// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseFixture} from "./BaseFixture.sol";

contract PositionManagerEmergencyTest is BaseFixture {
    uint256 constant ICR_DELTA = 0.000075e18;

    function testTopupEmergency() public {
        _triggerEmergencyOps();
    }

    function testTopupEmergency_When_priorReduction(uint256 _collReduction) public {
        uint256 limitor = COLLATERAL.getPooledEthByShares(
            CDP_MANAGER.getCdpCollShares(positionManagerCrEmergency.TREASURY_CDP_ID())
        ) / 4;
        _collReduction = bound(_collReduction, 2e18, limitor);

        vm.startPrank(TREASURY);
        BORROW_OPERATIONS.withdrawColl(
            positionManagerCrEmergency.TREASURY_CDP_ID(), _collReduction, bytes32(0), bytes32(0)
        );

        // _triggerEmergencyOps();
    }

    function _triggerEmergencyOps() internal {
        uint256 icrBefore =
            CDP_MANAGER.getSyncedICR(positionManagerCrEmergency.TREASURY_CDP_ID(), EBTC_FEED.fetchPrice());

        bool isCrBelowThreshold = positionManagerCrEmergency.isCrBelowThreshold();
        assertTrue(isCrBelowThreshold);

        vm.prank(RANDOM_RM_AGENT);
        positionManagerCrEmergency.mitigateRisk();
        vm.stopPrank();

        uint256 icrAfter =
            CDP_MANAGER.getSyncedICR(positionManagerCrEmergency.TREASURY_CDP_ID(), EBTC_FEED.fetchPrice());
        assertGe(icrAfter, icrBefore);
        assertApproxEqAbs(icrAfter, positionManagerCrEmergency.TARGET_CR(), ICR_DELTA);
    }
}
