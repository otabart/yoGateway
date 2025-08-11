// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {YoGateway} from "../src/YoGateway.sol";

contract DeployYoGateway is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY"); // EOA used to deploy (will be initial owner)
        vm.startBroadcast(pk);
        YoGateway gateway = new YoGateway(); // constructor pre-seeds the 3 yoVaults
        vm.stopBroadcast();

        console2.log("YoGateway deployed at:", address(gateway));
    }
}
