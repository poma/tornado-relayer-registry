// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { ImmutableGovernanceInformation } from "../submodules/tornado-lottery-period/contracts/ImmutableGovernanceInformation.sol";

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { LoopbackProxy } from "tornado-governance/contracts/LoopbackProxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { GovernanceStakingUpgrade } from "./governance-upgrade/GovernanceStakingUpgrade.sol";
import { TornadoStakingRewards } from "./staking/TornadoStakingRewards.sol";
import { RelayerRegistry } from "./RelayerRegistry.sol";
import { RelayerRegistryData } from "./registry-data/RelayerRegistryData.sol";
import { TornadoInstancesData } from "./tornado-proxy/TornadoInstancesData.sol";

import { TornadoProxy } from "tornado-anonymity-mining/contracts/TornadoProxy.sol";

contract RelayerRegistryProposal is ImmutableGovernanceInformation {
  using SafeMath for uint256;

  address public constant GovernanceVesting = 0x179f48C78f57A3A78f0608cC9197B8972921d1D2;
  IERC20 public constant tornToken = IERC20(TornTokenAddress);

  RelayerRegistry public immutable Registry;
  TornadoStakingRewards public immutable Staking;
  TornadoInstancesData public immutable InstancesData;

  address public immutable oldTornadoProxy;
  address public immutable newTornadoProxy;
  address public immutable gasCompLogic;
  address public immutable tornadoVault;
  address public immutable registryData;

  constructor(
    address relayerRegistryAddress,
    address registryDataAddress,
    address oldTornadoProxyAddress,
    address newTornadoProxyAddress,
    address stakingAddress,
    address tornadoInstancesDataAddress,
    address gasCompLogicAddress,
    address vaultAddress
  ) public {
    Registry = RelayerRegistry(relayerRegistryAddress);
    newTornadoProxy = newTornadoProxyAddress;
    oldTornadoProxy = oldTornadoProxyAddress;
    Staking = TornadoStakingRewards(stakingAddress);
    InstancesData = TornadoInstancesData(tornadoInstancesDataAddress);
    gasCompLogic = gasCompLogicAddress;
    tornadoVault = vaultAddress;
    registryData = registryDataAddress;
  }

  function executeProposal() external {
    LoopbackProxy(returnPayableGovernance()).upgradeTo(
      address(new GovernanceStakingUpgrade(address(Staking), registryData, gasCompLogic, tornadoVault))
    );

    GovernanceStakingUpgrade newGovernance = GovernanceStakingUpgrade(returnPayableGovernance());

    Registry.registerProxy(newTornadoProxy);

    RelayerRegistryData RegistryData = Registry.RegistryData();

    RegistryData.setProtocolFee(1e15);
    RegistryData.setProtocolPeriod(5400);

    Staking.setDistributionPeriod(365 days);

    Registry.setMinStakeAmount(1e20);

    require(disableOldProxy());
  }

  function disableOldProxy() private returns (bool) {
    TornadoProxy oldProxy = TornadoProxy(oldTornadoProxy);
    TornadoProxy.Tornado[] memory Instances = InstancesData.getInstances();

    for (uint256 i = 0; i < Instances.length; i++) {
      oldProxy.updateInstance(Instances[i]);
    }

    return true;
  }
}
