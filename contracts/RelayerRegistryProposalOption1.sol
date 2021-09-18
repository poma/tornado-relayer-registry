// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { ImmutableGovernanceInformation } from "../submodules/tornado-lottery-period/contracts/ImmutableGovernanceInformation.sol";
import { TornadoVault } from "../submodules/tornado-lottery-period/contracts/vault/TornadoVault.sol";
import { IGovernanceVesting } from "../submodules/tornado-lottery-period/contracts/interfaces/IGovernanceVesting.sol";

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { LoopbackProxy } from "tornado-governance/contracts/LoopbackProxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { GovernanceStakingUpgradeOption1 } from "./governance-upgrade/GovernanceStakingUpgradeOption1.sol";
import { TornadoStakingRewards } from "./staking/TornadoStakingRewards.sol";
import { RelayerRegistry } from "./RelayerRegistry.sol";

import { TornadoProxy } from "tornado-anonymity-mining/contracts/TornadoProxy.sol";
import { ITornadoInstance } from "tornado-anonymity-mining/contracts/interfaces/ITornadoInstance.sol";

contract RelayerRegistryProposalOption1 is ImmutableGovernanceInformation {
  using SafeMath for uint256;

  address public constant GovernanceVesting = 0x179f48C78f57A3A78f0608cC9197B8972921d1D2;
  IERC20 public constant tornToken = IERC20(TornTokenAddress);

  RelayerRegistry public immutable registry;

  address public immutable oldTornadoProxy;
  address public immutable newTornadoProxy;
  address public immutable staking;

  constructor(
    address relayerRegistryAddress,
    address oldTornadoProxyAddress,
    address newTornadoProxyAddress,
    address stakingAddress
  ) public {
    registry = RelayerRegistry(relayerRegistryAddress);
    newTornadoProxy = newTornadoProxyAddress;
    staking = stakingAddress;
    oldTornadoProxy = oldTornadoProxyAddress;
  }

  function executeProposal() external {
    uint256 totalOutflowsOfProposalExecutions = 120000000000000000000000 + 22916666666666666666666 + 54999999999999969408000 - 27e18;

    uint256 lockedTokenBalancesInGovernance = IGovernanceVesting(GovernanceVesting).released().sub(
      totalOutflowsOfProposalExecutions
    );

    address vault = address(new TornadoVault());

    LoopbackProxy(returnPayableGovernance()).upgradeTo(address(new GovernanceStakingUpgradeOption1(staking, vault)));

    GovernanceStakingUpgradeOption1 newGovernance = GovernanceStakingUpgradeOption1(GovernanceAddress);

    registry.registerProxy(newTornadoProxy);

    require(
      tornToken.transfer(
        address(newGovernance.userVault()),
        (tornToken.balanceOf(address(this))).sub(lockedTokenBalancesInGovernance)
      ),
      "TORN: transfer failed"
    );
  }
}