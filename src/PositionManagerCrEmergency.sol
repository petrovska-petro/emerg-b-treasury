// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ICollateralToken} from "@ebtc/contracts/Dependencies/ICollateralToken.sol";
import {EbtcFeed} from "@ebtc/contracts/EbtcFeed.sol";
import {IPriceFeed} from "@ebtc/contracts/Interfaces/IPriceFeed.sol";
import {ICdpManager} from "@ebtc/contracts/Interfaces/ICdpManager.sol";
import {IBorrowerOperations} from "@ebtc/contracts/Interfaces/IBorrowerOperations.sol";

/// @title PositionManagerCrEmergency
/// @notice This contract is responsible for managing the treasury CDP in case of an emergency
contract PositionManagerCrEmergency {
    /// @notice The address of the treasury safe (https://etherscan.io/address/0xD0A7A8B98957b9CD3cFB9c0425AbE44551158e9e)
    address public constant TREASURY = 0xD0A7A8B98957b9CD3cFB9c0425AbE44551158e9e;

    /// @notice The threshold for the collateral ratio to be considered in an emergency state
    uint256 public constant THRESHOLD_CR = 1.55e18;

    /// @notice The target collateral ratio for the treasury CDP
    uint256 public constant TARGET_CR = 1.75e18;

    /// @notice The ID of the treasury CDP (https://ebtc.blockanalitica.com/cdps/d0a7a8b98957b9cd3cfb9c0425abe44551158e9e0129d4c80000000000000001)
    bytes32 public constant TREASURY_CDP_ID = 0xd0a7a8b98957b9cd3cfb9c0425abe44551158e9e0129d4c80000000000000001;

    // https://etherscan.io/address/0xae7ab96520de3a18e5e111b5eaab095312d7fe84
    ICollateralToken COLLATERAL = ICollateralToken(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    EbtcFeed EBTC_FEED = EbtcFeed(0xa9a65B1B1dDa8376527E89985b221B6bfCA1Dc9a);

    ICdpManager CDP_MANAGER = ICdpManager(0xc4cbaE499bb4Ca41E78f52F07f5d98c375711774);

    IBorrowerOperations BORROW_OPERATIONS = IBorrowerOperations(0xd366e016Ae0677CdCE93472e603b75051E022AD0);

    address public rmAgent;

    error NotRmAgent(address caller);
    error NotTreasury(address caller);
    error CrIsAboveThreshold();

    event RiskMitigated(string message, uint256 collRequired, uint256 timestamp);

    modifier onlyRmAgent() {
        if (msg.sender != rmAgent) revert NotRmAgent(msg.sender);
        _;
    }

    modifier OnlyTreasury() {
        if (msg.sender != TREASURY) revert NotTreasury(msg.sender);
        _;
    }

    constructor() {
        // approve collateral in BO
        COLLATERAL.approve(address(BORROW_OPERATIONS), type(uint256).max);
    }

    /// @notice Updates the risk manager agent address
    /// @param _rmAgent The address of the risk manager agent
    function setRmAgent(address _rmAgent) external OnlyTreasury {
        rmAgent = _rmAgent;
    }

    /// @notice Returns a boolean indicating if the collateral ratio is safe
    /// @dev Mind that [fetchPrice()] changes the state of the ebtc price feed
    /// @return isCrBelowThreshold_ True if the collateral ratio is below or equal to THRESHOLD_CR or false otherwise
    function isCrBelowThreshold() public returns (bool isCrBelowThreshold_) {
        // @note force to update price to get latest and cached into `lastGoodPrice`
        if (CDP_MANAGER.getSyncedICR(TREASURY_CDP_ID, EBTC_FEED.fetchPrice()) <= THRESHOLD_CR) {
            isCrBelowThreshold_ = true;
        }
    }

    /// @notice Returns the amount of collateral required to reach the TARGET_CR
    /// @return collRequired_ The amount of collateral required to reach the TARGET_CR
    function _requireCollateralToTarget() internal view returns (uint256 collRequired_) {
        // @note latest price should had being stored in `lastGoodPrice` from previous atomic call
        // @note math: x = (icr * debt) / price
        (uint256 currentDebt, uint256 currentCollShares) = CDP_MANAGER.getSyncedDebtAndCollShares(TREASURY_CDP_ID);
        uint256 totalCollRequired = TARGET_CR * currentDebt / EBTC_FEED.lastGoodPrice();
        collRequired_ = totalCollRequired - COLLATERAL.getPooledEthByShares(currentCollShares);
    }

    /// @notice Mitigates the risk of the treasury cdp going significatly below 150% CR, pushing it towards 175%
    function mitigateRisk() external onlyRmAgent {
        if (!isCrBelowThreshold()) revert CrIsAboveThreshold();
        // calculate collateral required
        uint256 collRequired = _requireCollateralToTarget();
        // pull exact collateral from treasury
        COLLATERAL.transferFrom(TREASURY, address(this), collRequired);
        // top up collateral
        BORROW_OPERATIONS.addColl(TREASURY_CDP_ID, TREASURY_CDP_ID, TREASURY_CDP_ID, collRequired);
        emit RiskMitigated("emerg-collateral-added", collRequired, block.timestamp);
    }
}
