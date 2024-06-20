// SPDX-License-Identifier: MIT 
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../ArgusWrapper.sol"; 

//This is just a mock Gov contract for PoC. 
//This smart contract should incorporate workflows for decentralized voting in an ideal world.
//Otherwise this will be a centralization point for the vaults. Then, multisig owner is a must.
contract MockGovernance is Ownable {
    ArgusWrappedToken public argusWrappedToken;

    constructor(address _argusWrappedToken) Ownable() {
        argusWrappedToken = ArgusWrappedToken(_argusWrappedToken);
    }

    // Function for the owner to approve a pending transaction
    function approveTransaction(address _from, address _to, uint256 _amount) public onlyOwner {
        argusWrappedToken.approveTransaction(_from, _to, _amount);
    }

    // Function for the owner to reject a pending transaction
    function rejectTransaction(address _from, address _to, uint256 _amount) public onlyOwner {
        argusWrappedToken.rejectTransaction(_from, _to, _amount);
    }
}