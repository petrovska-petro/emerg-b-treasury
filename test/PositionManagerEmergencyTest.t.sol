// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseFixture} from "./BaseFixture.sol";

contract PositionManagerEmergencyTest is BaseFixture {
    uint256 constant ICR_DELTA = 0.000075e18;

    function testTopupEmergency() public {
        uint256 icrBefore =
            CDP_MANAGER.getSyncedICR(positionManagerCrEmergency.TREASURY_CDP_ID(), EBTC_FEED.fetchPrice());

        bool isCrBelowThreshold = positionManagerCrEmergency.isCrBelowThreshold();
        assertTrue(isCrBelowThreshold);

        vm.prank(RANDOM_RM_AGENT);
        positionManagerCrEmergency.mitigateRisk();

        uint256 icrAfter =
            CDP_MANAGER.getSyncedICR(positionManagerCrEmergency.TREASURY_CDP_ID(), EBTC_FEED.fetchPrice());
        assertGe(icrAfter, icrBefore);
        assertApproxEqAbs(icrAfter, positionManagerCrEmergency.TARGET_CR(), ICR_DELTA);
    }
}
