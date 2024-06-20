// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ArgusWrapper.sol";
import "../src/mocks/ArgusGov.sol";
import "../src/mocks/MockERC20.sol";

contract ArgusWrappedTokenTest is Test {
    ArgusWrappedToken argusWrappedToken;
    MockGovernance mockGovernance;
    MockERC20 originalToken;

    address alice = address(1);
    address bob = address(2);
    uint256 initialSupply = 1000 * 10 ** 18;

    event TransactionPending(address indexed from, address indexed to, uint256 amount, bytes32 transactionHash);

    function setUp() public {
        // Deploy a mock ERC20 token to represent the original token
        originalToken = new MockERC20("Original Token", "OT");
        originalToken.mint(alice, initialSupply);

        // Deploy the MockGovernance contract 
        mockGovernance = new MockGovernance(address(this));

        // Deploy the ArgusWrappedToken contract
        argusWrappedToken = new ArgusWrappedToken(
            "Argus Wrapped Token",
            "AWT",
            address(mockGovernance)
        );

        // Set the governance contract in ArgusWrappedToken
        argusWrappedToken.setGovernanceContract(address(mockGovernance));
    }

    // Test 1: Successful wrap and unwrap with no threshold issues
    function testWrapUnwrap() public {
        uint256 amountToWrap = 100 * 10 ** 18;

        // Approve the wrap
        vm.prank(alice);
        originalToken.approve(address(argusWrappedToken), amountToWrap);

        // Wrap the tokens
        vm.prank(alice);
        argusWrappedToken.wrap(amountToWrap, address(originalToken)); // Pass originalToken

        assertEq(argusWrappedToken.balanceOf(alice), amountToWrap);
        assertEq(originalToken.balanceOf(address(argusWrappedToken)), amountToWrap);

        // Unwrap the tokens
        vm.prank(alice);
        argusWrappedToken.unwrap(amountToWrap, address(originalToken)); // Pass originalToken

        assertEq(argusWrappedToken.balanceOf(alice), 0);
        assertEq(originalToken.balanceOf(alice), initialSupply);
    }

    // Test 2: Transaction exceeding threshold - triggers pending state
    function testTransactionPending() public {
        uint256 threshold = 50 * 10 ** 18;
        uint256 transferAmount = 60 * 10 ** 18;

        // Set Alice's threshold
        vm.startPrank(alice);
        argusWrappedToken.setThreshold(threshold);

        // Wrap some tokens first
        originalToken.approve(address(argusWrappedToken), transferAmount);
        argusWrappedToken.wrap(transferAmount, address(originalToken));

        // Attempt a transfer that exceeds the threshold
        vm.expectEmit(true, true, true, true);
        emit TransactionPending(alice, bob, transferAmount, keccak256(abi.encodePacked(alice, bob, transferAmount, argusWrappedToken._nonce())));
        argusWrappedToken.transfer(bob, transferAmount); 
        vm.stopPrank();
    }

    // Test 3: Governance approves pending transaction
    function testGovernanceApproveTransaction() public {
        uint256 threshold = 50 * 10 ** 18;
        uint256 transferAmount = 60 * 10 ** 18;

        // Set Alice's threshold and wrap tokens
        vm.startPrank(alice);
        argusWrappedToken.setThreshold(threshold);
        originalToken.approve(address(argusWrappedToken), transferAmount);
        argusWrappedToken.wrap(transferAmount, address(originalToken));
        vm.stopPrank();

        // Initiate the transfer that will be pending
        vm.prank(alice);
        argusWrappedToken.transfer(bob, transferAmount);

        // Approve the transaction as the governance contract
        vm.prank(address(mockGovernance));
        argusWrappedToken.approveTransaction(alice, bob, transferAmount);

        uint256 aliceBalance = argusWrappedToken.balanceOf(alice);
        uint256 bobBalance = argusWrappedToken.balanceOf(bob);

        // Check balances after successful approval
        assertEq(aliceBalance, 0); // Should be zero
        assertEq(bobBalance, transferAmount);
    }

    // Test 4: Governance rejects pending transaction
    function testGovernanceRejectTransaction() public {
        uint256 threshold = 50 * 10 ** 18;
        uint256 transferAmount = 60 * 10 ** 18;

        // Set Alice's threshold and wrap tokens
        vm.startPrank(alice);
        argusWrappedToken.setThreshold(threshold);
        originalToken.approve(address(argusWrappedToken), transferAmount);
        argusWrappedToken.wrap(transferAmount, address(originalToken));
        vm.stopPrank();

        // Initiate the transfer that will be pending
        vm.prank(alice);
        argusWrappedToken.transfer(bob, transferAmount);

        uint256 aliceBalance = argusWrappedToken.balanceOf(alice);
        uint256 bobBalance = argusWrappedToken.balanceOf(bob);

        // Reject the transaction as the governance contract
        vm.prank(address(mockGovernance));
        argusWrappedToken.rejectTransaction(alice, bob, transferAmount);

        // Balances should remain unchanged
        assertEq(argusWrappedToken.balanceOf(alice), aliceBalance); 
        assertEq(argusWrappedToken.balanceOf(bob), bobBalance); 
    }
}
