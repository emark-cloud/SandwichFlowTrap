// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRouteController {
    function setProtectedRouting(address pool, bool enabled) external;
}

/// @notice Responds to toxic MEV flow detections from SandwichFlowTrap.
contract SandwichFlowResponder {
    address public owner;
    address public caller; // Drosera trap-config / relayer
    IRouteController public controller;

    uint8 public severityThreshold = 1; // min severity to act

    event ToxicOrderflowDetected(
        address indexed pool,
        uint8 severity,
        uint16 numSandwiches,
        uint256 totalVictimVolume,
        uint256 attackerProfit,
        uint16 worstPriceImpactBps,
        uint8 badBlocks,
        uint256 window,
        uint256 sumVictimVolume,
        address[] attackers,
        bytes32 reasonHash
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyCaller() {
        require(msg.sender == caller, "UNAUTHORIZED_CALLER");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
    }

    function setCaller(address c) external onlyOwner {
        caller = c;
    }

    function setController(address c) external onlyOwner {
        controller = IRouteController(c);
    }

    function setSeverityThreshold(uint8 s) external onlyOwner {
        severityThreshold = s;
    }

    /// @notice Called by Drosera when SandwichFlowTrap returns (true, payload)
    function handle(bytes calldata payload) external onlyCaller {
        (
            uint8 severity,
            address pool,
            uint16 numSandwiches,
            uint256 totalVictimVolume,
            uint256 attackerProfit,
            uint16 worstPriceImpactBps,
            uint8 badBlocks,
            uint256 window,
            uint256 sumVictimVolume,
            address[] memory attackers
        ) = abi.decode(
            payload,
            (
                uint8,
                address,
                uint16,
                uint256,
                uint256,
                uint16,
                uint8,
                uint256,
                uint256,
                address[]
            )
        );

        if (severity < severityThreshold) return;

        bytes32 reasonHash = keccak256(
            abi.encodePacked(
                "MEV_SANDWICH_TOXIC_FLOW",
                pool,
                severity,
                numSandwiches,
                attackerProfit,
                worstPriceImpactBps,
                badBlocks,
                window
            )
        );

        // Optional: enable protected routing for that pool
        if (address(controller) != address(0)) {
            controller.setProtectedRouting(pool, true);
        }

        emit ToxicOrderflowDetected(
            pool,
            severity,
            numSandwiches,
            totalVictimVolume,
            attackerProfit,
            worstPriceImpactBps,
            badBlocks,
            window,
            sumVictimVolume,
            attackers,
            reasonHash
        );
    }
}

