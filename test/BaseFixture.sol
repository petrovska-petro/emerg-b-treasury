// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {ICollateralToken} from "@ebtc/contracts/Dependencies/ICollateralToken.sol";
import {EbtcFeed} from "@ebtc/contracts/EbtcFeed.sol";
import {IPriceFeed} from "@ebtc/contracts/Interfaces/IPriceFeed.sol";
import {ICdpManager} from "@ebtc/contracts/Interfaces/ICdpManager.sol";
import {IBorrowerOperations} from "@ebtc/contracts/Interfaces/IBorrowerOperations.sol";
import {IPositionManagers} from "@ebtc/contracts/Interfaces/IPositionManagers.sol";

import {PositionManagerCrEmergency} from "../src/PositionManagerCrEmergency.sol";

contract BaseFixture is Test {
    PositionManagerCrEmergency positionManagerCrEmergency;

    address public constant RANDOM_RM_AGENT = address(3747483);

    address public constant TREASURY = 0xD0A7A8B98957b9CD3cFB9c0425AbE44551158e9e;

    EbtcFeed EBTC_FEED = EbtcFeed(0xa9a65B1B1dDa8376527E89985b221B6bfCA1Dc9a);
    ICollateralToken COLLATERAL = ICollateralToken(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ICdpManager CDP_MANAGER = ICdpManager(0xc4cbaE499bb4Ca41E78f52F07f5d98c375711774);
    IBorrowerOperations BORROW_OPERATIONS = IBorrowerOperations(0xd366e016Ae0677CdCE93472e603b75051E022AD0);

    function setUp() public {
        // fork before treasury top up
        vm.createSelectFork("mainnet", 20885869);

        positionManagerCrEmergency = new PositionManagerCrEmergency();

        vm.startPrank(TREASURY);
        // @audit in production max uint256 is not a good practice, tbd
        COLLATERAL.approve(address(positionManagerCrEmergency), type(uint256).max);
        // @audit probably one off approval makes more sense in prod
        BORROW_OPERATIONS.setPositionManagerApproval(
            address(positionManagerCrEmergency), IPositionManagers.PositionManagerApproval.OneTime
        );
        positionManagerCrEmergency.setRmAgent(RANDOM_RM_AGENT);
        vm.stopPrank();

        vm.label(address(TREASURY), "TREASURY");
        vm.label(RANDOM_RM_AGENT, "RANDOM_RM_AGENT");
        vm.label(address(COLLATERAL), "COLLATERAL");
        vm.label(address(EBTC_FEED), "EBTC_FEED");
        vm.label(address(BORROW_OPERATIONS), "BORROW_OPERATIONS");
        vm.label(address(CDP_MANAGER), "CDP_MANAGER");
        vm.label(address(positionManagerCrEmergency), "POSITION_MANAGER");
    }
    // multisig operations:
    // 1. coll.approve
    // 2. bo.setPositionManagerApproval
    // 3. posmanager.setRmAgent
}
