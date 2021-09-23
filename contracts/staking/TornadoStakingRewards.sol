// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/0.6.x/token/ERC20/IERC20.sol";
import { SafeMath } from "@openzeppelin/0.6.x/math/SafeMath.sol";

contract TornadoStakingRewards {
  using SafeMath for uint256;

  address public immutable governance;
  uint256 public immutable ratioConstant;
  IERC20 public immutable TORN;

  uint256 public currentSharePrice;
  uint256 public distributionPeriod;
  uint256 public lockedAmount;
  uint256 public startTime;

  mapping(address => uint256) public getLastActivityTimestampForAccount;

  constructor(
    address governanceAddress,
    address tornAddress,
    uint256 initialLockedAmount
  ) public {
    governance = governanceAddress;
    TORN = IERC20(tornAddress);
    ratioConstant = IERC20(tornAddress).totalSupply();
    lockedAmount = initialLockedAmount;
  }

  modifier onlyGovernance() {
    require(msg.sender == address(governance));
    _;
  }

  function addStake(address sender, uint256 tornAmount) external {
    require(TORN.transferFrom(sender, address(this), tornAmount), "tf_fail");
    // will throw if block.timestamp - startTime > distributionPeriod
    currentSharePrice = currentSharePrice.add(
      tornAmount.mul(ratioConstant).div(lockedAmount).div(distributionPeriod.sub(block.timestamp.sub(startTime)))
    );
  }

  function rebaseSharePriceOnLock(uint256 amount) external onlyGovernance {
    uint256 newLockedAmount = lockedAmount.add(amount);
    currentSharePrice = currentSharePrice.mul(lockedAmount).div(newLockedAmount);
    lockedAmount = newLockedAmount;
  }

  function rebaseSharePriceOnUnlock(uint256 amount) external onlyGovernance {
    uint256 newLockedAmount = lockedAmount.sub(amount);
    currentSharePrice = currentSharePrice.mul(lockedAmount).div(newLockedAmount);
    lockedAmount = newLockedAmount;
  }

  function setDistributionPeriod(uint256 period) external onlyGovernance {
    distributionPeriod = period;
    startTime = block.timestamp;
  }

  function governanceClaimFor(
    address account,
    address recipient,
    uint256 amountLockedBeforehand
  ) external onlyGovernance returns (uint256) {
    return _calculateAndPayReward(account, recipient, amountLockedBeforehand);
  }

  function _calculateAndPayReward(
    address account,
    address recipient,
    uint256 amountLockedBeforehand
  ) private returns (uint256 claimed) {
    if (getLastActivityTimestampForAccount[account] == 0) getLastActivityTimestampForAccount[account] = startTime;
    claimed = amountLockedBeforehand
      .mul(block.timestamp.sub(getLastActivityTimestampForAccount[account]))
      .mul(currentSharePrice)
      .div(ratioConstant);
    require(TORN.transfer(recipient, claimed));
    getLastActivityTimestampForAccount[account] = block.timestamp;
  }
}
