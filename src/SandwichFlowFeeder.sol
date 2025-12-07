// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Stores per-block MEV sandwich/toxic flow stats for a specific pool.
contract SandwichFlowFeeder {
    struct BlockMetrics {
        uint64 ts;                  // unix timestamp from operator
        address pool;               // target AMM pool
        uint16 numSandwiches;       // sandwiches detected in this block
        uint256 totalVictimVolume;  // sum of victim notional (e.g. in stable units)
        uint256 attackerProfit;     // attacker net profit in token units
        uint16 worstPriceImpactBps; // max victim price impact in bps (1e4 = 100%)
        address[] attackers;        // unique attacker addresses in this block
    }

    address public owner;
    BlockMetrics private latest;

    event MetricsPushed(
        uint64 ts,
        address indexed pool,
        uint16 numSandwiches,
        uint256 totalVictimVolume,
        uint256 attackerProfit,
        uint16 worstPriceImpactBps,
        uint256 attackerCount
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
    }

    /// @notice Called by your off-chain MEV/mempool scanner once per block (or window).
    function pushMetrics(
        uint64 ts,
        address pool,
        uint16 numSandwiches,
        uint256 totalVictimVolume,
        uint256 attackerProfit,
        uint16 worstPriceImpactBps,
        address[] calldata attackers
    ) external onlyOwner {
        BlockMetrics storage m = latest;

        m.ts = ts;
        m.pool = pool;
        m.numSandwiches = numSandwiches;
        m.totalVictimVolume = totalVictimVolume;
        m.attackerProfit = attackerProfit;
        m.worstPriceImpactBps = worstPriceImpactBps;

        delete m.attackers;
        for (uint256 i = 0; i < attackers.length; i++) {
            m.attackers.push(attackers[i]);
        }

        emit MetricsPushed(
            ts,
            pool,
            numSandwiches,
            totalVictimVolume,
            attackerProfit,
            worstPriceImpactBps,
            attackers.length
        );
    }

    /// @notice Read-only view used by the trap’s collect().
    function getLatest()
        external
        view
        returns (
            uint64 ts,
            address pool,
            uint16 numSandwiches,
            uint256 totalVictimVolume,
            uint256 attackerProfit,
            uint16 worstPriceImpactBps,
            address[] memory attackers
        )
    {
        BlockMetrics storage m = latest;

        uint256 len = m.attackers.length;
        attackers = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            attackers[i] = m.attackers[i];
        }

        return (
            m.ts,
            m.pool,
            m.numSandwiches,
            m.totalVictimVolume,
            m.attackerProfit,
            m.worstPriceImpactBps,
            attackers
        );
    }
}

