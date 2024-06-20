// SPDX-License-Identifier: MIT 
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ArgusWrappedToken is ERC20, Ownable, ReentrancyGuard {
    event TransactionPending(address indexed from, address indexed to, uint256 amount, bytes32 transactionHash);
    event TransactionApproved(address indexed from, address indexed to, uint256 amount, bytes32 transactionHash);
    event TransactionRejected(address indexed from, address indexed to, uint256 amount, bytes32 transactionHash);
    event Wrapped(address indexed user, uint256 amount, address originalToken);
    event Unwrapped(address indexed user, uint256 amount, address originalToken);

    // Mapping of user addresses to their set thresholds
    mapping(address => uint256) public userThresholds;
    // Mapping of transaction hashes to booleans indicating if they're pending
    mapping(bytes32 => bool) public pendingTransactions;
    // Governance contract address (Multi-Sig or DAO)
    address public governanceContract;
    // Nonce to make transaction hashes unique
    uint256 public nonce;

    constructor(
        string memory _name, 
        string memory _symbol, 
        address _governanceContract
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        governanceContract = _governanceContract; 
    }

    // Allow users to set their own transaction thresholds
    function setThreshold(uint256 _threshold) public {
        userThresholds[msg.sender] = _threshold;
    }

    function setGovernanceContract(address _newGovernanceContract) public onlyOwner {
        governanceContract = _newGovernanceContract;
    }

    // Override transfer() to include threshold and pending checks
    function transfer(address to, uint256 amount) public nonReentrant override returns (bool) {
        address sender = _msgSender();
        _transferWithCheck(sender, to, amount);
        return true;
    }

    // Override transferFrom() to include threshold and pending checks
    function transferFrom(address from, address to, uint256 amount) public  nonReentrant override returns (bool){
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithCheck(from, to, amount);
        return true;
    }

    // Internal function to perform transfers with security checks
    function _transferWithCheck(address from, address to, uint256 amount) internal {
        // Exclude governance contract
        if (from != governanceContract && to != governanceContract) { 
            bytes32 txHash = keccak256(abi.encodePacked(from, to, amount, nonce));

            if (amount >= userThresholds[from] && !pendingTransactions[txHash]) {
                pendingTransactions[txHash] = true;
                emit TransactionPending(from, to, amount, txHash);
            } else {
                _transfer(from, to, amount); // Execute the transfer if not pending
            }

        } else {
            _transfer(from, to, amount);
        }
    }

    // Function to be called by the governance contract to approve a transaction
    function approveTransaction(address _from, address _to, uint256 _amount) public {
        require(msg.sender == governanceContract, "Only the governance contract can approve transactions");
        bytes32 txHash = keccak256(abi.encodePacked(_from, _to, _amount, nonce));
        if (pendingTransactions[txHash]) {
            delete pendingTransactions[txHash];
            nonce++;
            _transfer(_from, _to, _amount); 
            emit TransactionApproved(_from, _to, _amount, txHash); 
            return;
        }
        revert("Transaction is not pending");
    }

    // Function to be called by the governance contract to reject a transaction
    function rejectTransaction(address _from, address _to, uint256 _amount) public {
        require(msg.sender == governanceContract, "Only the governance contract can reject transactions");
        bytes32 txHash = keccak256(abi.encodePacked(_from, _to, _amount, nonce));
        if (pendingTransactions[txHash]) {
            nonce++;
            delete pendingTransactions[txHash];

            emit TransactionRejected(_from, _to, _amount, txHash);
            // No need to do anything else here, as the transaction was already blocked
            return;
        }
        revert("Transaction is not pending");
    }

    function wrap(uint256 _amount, address _originalToken) public nonReentrant{
        require(_amount > 0, "Wrap amount must be greater than zero");

        // Create an IERC20 instance for the original token
        IERC20 originalToken = IERC20(_originalToken);

        // Transfer original tokens from user to contract
        originalToken.transferFrom(msg.sender, address(this), _amount);

        // Mint wrapped tokens to the user
        _mint(msg.sender, _amount);
        emit Wrapped(msg.sender, _amount, _originalToken); // Emit original token address
    }

    // Unwrap wrapped tokens 
    function unwrap(uint256 _amount, address _originalToken) public nonReentrant{
        require(_amount > 0, "Unwrap amount must be greater than zero");
        require(balanceOf(msg.sender) >= _amount, "Insufficient wrapped token balance");
        
        IERC20 originalToken = IERC20(_originalToken);

        // Burn wrapped tokens
        _burn(msg.sender, _amount);

        // Transfer original tokens back to user
        originalToken.transfer(msg.sender, _amount);
        emit Unwrapped(msg.sender, _amount, _originalToken);
    }
}
