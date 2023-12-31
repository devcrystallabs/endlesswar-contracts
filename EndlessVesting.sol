// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EndlessVesting is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public vestedAmount;
    mapping(address => uint256) public claimedAmount;

    uint256 public immutable start;
    uint256 public immutable end;
    uint256 public immutable open;
    IERC20 public immutable token;
    uint256 public immutable duration;
    uint256 public immutable unlockPercentsOnStart;

    event NewVesting(address indexed investor, uint256 amount);
    event Claimed(address indexed investor, uint256 amount, uint256 left);

    constructor(uint256 _open, uint256 _start, uint256 _end, uint256 _unlockPercentsOnStart, IERC20 _token) {
        require(_end > _start, "EGS");
        require(_unlockPercentsOnStart < 10000, "PTH");

        open = _open;
        start = _start;
        end = _end;
        token = _token;
        duration = _end - _start;
        unlockPercentsOnStart = _unlockPercentsOnStart;

    }

    function addInvestors(address[] memory investors, uint256[] memory amounts) external onlyOwner {
        uint256 totalAmount = 0;
        uint256 length = investors.length;
        require(amounts.length == length, "ICL");

        for (uint256 i = 0; i < length; i++) {
            vestedAmount[investors[i]] += amounts[i];
            totalAmount += amounts[i];
            emit NewVesting(investors[i], amounts[i]);
        }

        token.safeTransferFrom(msg.sender, address(this), totalAmount);
    }

    function addInvestor(address investor, uint256 amount) external onlyOwner {
        vestedAmount[investor] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit NewVesting(investor, amount);
    }

    function removeInvestors(address[] memory investors) external onlyOwner {
        uint256 totalAmount = 0;
        uint256 length = investors.length;
        for (uint256 i = 0; i < length; i++) {
            totalAmount += vestedAmount[investors[i]];
            totalAmount -= claimedAmount[investors[i]];
            vestedAmount[investors[i]] = 0;
            claimedAmount[investors[i]] = 0;
            delete vestedAmount[investors[i]];
            delete claimedAmount[investors[i]];
        }

        token.transfer(msg.sender, totalAmount);
    }


    function claim() external {
        address investor = msg.sender;
        claimFor(investor);
    }

    function claimFor(address investor) public {
        require(block.timestamp >= open, "NO");
        uint256 claimable = claimableAmount(investor);
        uint256 totalUnclaimed = vestedAmount[investor] - claimedAmount[investor];

        claimedAmount[investor] += claimable;
        emit Claimed(investor, claimedAmount[investor], totalUnclaimed-claimable);

        token.safeTransfer(investor, claimable);
    }

    function claimableAmount(address investor) public view returns (uint256) {
        return _vestedAmount(investor) - claimedAmount[investor];
    }

    function _vestedAmount(address investor) private view returns (uint256) {
        uint256 _vested = vestedAmount[investor];
        uint256 unlockAtStart = _vested * unlockPercentsOnStart / 10000;

        if (block.timestamp < start) {
            if ( block.timestamp < open ) {
                return 0;
            } else {
                return unlockAtStart;
            }
        } else if (block.timestamp >= start + duration) {
            return _vested;
        } else {
            return unlockAtStart + ((_vested - unlockAtStart) * (block.timestamp - start) / duration);
        }
    }
}