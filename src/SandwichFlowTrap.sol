// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "./interfaces/ITrap.sol";

interface ISandwichFlowFeeder {
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
        );
}

contract SandwichFlowTrap is ITrap {
    /* -------------------------------------------------------------------------- */
    /*                                   TYPES                                    */
    /* -------------------------------------------------------------------------- */

    struct BlockMetrics {
        uint64 ts;
        address pool;
        uint16 numSandwiches;
        uint256 totalVictimVolume;
        uint256 attackerProfit;
        uint16 worstPriceImpactBps;
        address[] attackers;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                   */
    /* -------------------------------------------------------------------------- */

    address public feeder;
    address public owner;

    constructor() {
        owner = address(0); // Drosera deploys; set owner after
    }

    function setOwner(address newOwner) external {
        require(owner == address(0), "OWNER_ALREADY_SET");
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
    }

    function setFeeder(address f) external {
        require(msg.sender == owner, "NOT_OWNER");
        require(f != address(0), "ZERO_FEEDER");
        feeder = f;
    }

    /* -------------------------------------------------------------------------- */
    /*                             TUNED THRESHOLDS (CONST)                        */
    /* -------------------------------------------------------------------------- */

   
    uint16 public constant SANDWICH_THRESHOLD = 2;

    
    uint16 public constant IMPACT_THRESHOLD_BPS = 500;
    uint16 public constant SCARY_IMPACT_BPS   = 1000; 

   
    uint256 public constant PROFIT_THRESHOLD      = 10e18;  
    uint256 public constant HUGE_PROFIT_THRESHOLD = 50e18;  

   
    uint8 public constant MIN_BAD_BLOCKS = 2;

    /* -------------------------------------------------------------------------- */
    /*                                   COLLECT                                   */
    /* -------------------------------------------------------------------------- */

    function collect() external view override returns (bytes memory) {
        address f = feeder;
        if (f == address(0)) return bytes("");

        uint256 size;
        assembly {
            size := extcodesize(f)
        }
        if (size == 0) return bytes("");

        try ISandwichFlowFeeder(f).getLatest() returns (
            uint64 ts,
            address pool,
            uint16 numSandwiches,
            uint256 totalVictimVolume,
            uint256 attackerProfit,
            uint16 worstPriceImpactBps,
            address[] memory attackers
        ) {
            BlockMetrics memory m = BlockMetrics({
                ts: ts,
                pool: pool,
                numSandwiches: numSandwiches,
                totalVictimVolume: totalVictimVolume,
                attackerProfit: attackerProfit,
                worstPriceImpactBps: worstPriceImpactBps,
                attackers: attackers
            });

            return abi.encode(m);
        } catch {
            return bytes("");
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               SHOULD RESPOND                               */
    /* -------------------------------------------------------------------------- */

    function shouldRespond(bytes[] calldata data)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (data.length == 0 || data[0].length == 0) return (false, "");

        // decode current block
        BlockMetrics memory curr = abi.decode(data[0], (BlockMetrics));
        if (curr.pool == address(0)) return (false, "");

        // window: look back up to last 5 samples (newest at data[0])
        uint256 window = data.length < 5 ? data.length : 5;

        uint8 badBlocks = 0;
        uint16 maxSandwiches = curr.numSandwiches;
        uint256 maxProfit = curr.attackerProfit;
        uint16 maxImpact = curr.worstPriceImpactBps;
        uint256 sumVictimVolume = 0;

        for (uint256 i = 0; i < window; i++) {
            if (data[i].length == 0) continue;

            BlockMetrics memory m = abi.decode(data[i], (BlockMetrics));
            if (m.pool != curr.pool) continue; 

            bool blockBad = _isBadBlock(
                m.numSandwiches,
                m.attackerProfit,
                m.worstPriceImpactBps
            );
            if (blockBad) badBlocks++;

            if (m.numSandwiches > maxSandwiches) maxSandwiches = m.numSandwiches;
            if (m.attackerProfit > maxProfit) maxProfit = m.attackerProfit;
            if (m.worstPriceImpactBps > maxImpact) maxImpact = m.worstPriceImpactBps;

            sumVictimVolume += m.totalVictimVolume;
        }

       
        if (badBlocks < MIN_BAD_BLOCKS) {
            
            if (!_isExtremeBlock(curr.numSandwiches, curr.attackerProfit, curr.worstPriceImpactBps)) {
                return (false, "");
            }
        }

       
        uint8 severity = 1;
        if (
            maxSandwiches >= SANDWICH_THRESHOLD * 3 ||
            maxProfit >= HUGE_PROFIT_THRESHOLD ||
            maxImpact >= SCARY_IMPACT_BPS
        ) {
            severity = 3;
        } else if (
            maxSandwiches >= SANDWICH_THRESHOLD * 2 ||
            maxProfit >= PROFIT_THRESHOLD * 2 ||
            maxImpact >= IMPACT_THRESHOLD_BPS * 2
        ) {
            severity = 2;
        }

        bytes memory payload = abi.encode(
            severity,
            curr.pool,
            curr.numSandwiches,
            curr.totalVictimVolume,
            curr.attackerProfit,
            curr.worstPriceImpactBps,
            badBlocks,
            window,
            sumVictimVolume,
            curr.attackers
        );

        return (true, payload);
    }

    /* -------------------------------------------------------------------------- */
    /*                              INTERNAL HELPERS                              */
    /* -------------------------------------------------------------------------- */

    function _isBadBlock(
        uint16 numSandwiches,
        uint256 attackerProfit,
        uint16 worstImpactBps
    ) internal pure returns (bool) {
        return (
            numSandwiches >= SANDWICH_THRESHOLD ||
            attackerProfit >= PROFIT_THRESHOLD ||
            worstImpactBps >= IMPACT_THRESHOLD_BPS
        );
    }

    function _isExtremeBlock(
        uint16 numSandwiches,
        uint256 attackerProfit,
        uint16 worstImpactBps
    ) internal pure returns (bool) {
        return (
            numSandwiches >= SANDWICH_THRESHOLD * 3 ||
            attackerProfit >= HUGE_PROFIT_THRESHOLD ||
            worstImpactBps >= SCARY_IMPACT_BPS
        );
    }
}

