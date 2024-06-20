// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ArgusWrapper.sol";
import "../src/mocks/ArgusGov.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 

contract Deploy is Script {
    function run() public {

        // Replace with proper
        address mockGovernance = address(0); 

        // Get the deployer address - this will be the address that executes the script
        address deployer = vm.addr(1); // You can change the account index if needed
        vm.startPrank(deployer);  // Start impersonating the deployer 
        
        //Deploy the ArgusWrappedToken contract
        ArgusWrappedToken argusWrappedToken = new ArgusWrappedToken(
            "Argus Wrapped Token",
            "AWT",
            address(mockGovernance) // Pass the governance contract 
        );

        vm.stopPrank(); 

        // Print out the deployed contract addresses
        console.log("ArgusWrappedToken deployed to:", address(argusWrappedToken));
    }
}