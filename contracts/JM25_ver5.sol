// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title JM25_ver5
 * @dev ERC20-like token with tax, burn, anti-whale, ownership features + maxTx/Wallet setters + multiTransfer for JM25 project
 */

contract JM25_ver5 {
    string public name = "JM25";
    string public symbol = "JM25";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public owner;
    address public daoWallet;

    uint256 public taxRate = 2; // DAO fee rate (%)
    uint256 public burnRate = 1; // Burn rate (%)
    bool public tradingEnabled = false;
    uint256 public launchTime;

    uint256 public maxTxLimit; // Maximum transaction amount for anti-whale
    uint256 public maxWalletLimit; // Maximum wallet holding amount for anti-whale

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isExcludedFromFees; // public → 자동 getter 생성됨

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _daoWallet) {
        owner = msg.sender;
        daoWallet = _daoWallet;
        totalSupply = 250_000_000 * 10 ** uint256(decimals);
        balanceOf[owner] = totalSupply;

        maxTxLimit = (totalSupply * 1) / 100; // 1% of total supply
        maxWalletLimit = (totalSupply * 2) / 100; // 2% of total supply

        isExcludedFromFees[owner] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[daoWallet] = true;

        launchTime = block.timestamp;

        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function enableTrading(bool _status) external onlyOwner {
        tradingEnabled = _status;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(tradingEnabled || from == owner, "Trading not enabled");
        require(value <= maxTxLimit, "Exceeds max transaction limit");

        if (!isExcludedFromFees[to]) {
            require(balanceOf[to] + value <= maxWalletLimit, "Exceeds max wallet limit");
        }

        uint256 daoAmount = 0;
        uint256 burnAmount = 0;
        uint256 sendAmount = value;

        if (!(isExcludedFromFees[from] || isExcludedFromFees[to])) {
            daoAmount = (value * taxRate) / 100;
            burnAmount = (value * burnRate) / 100;
            sendAmount = value - daoAmount - burnAmount;

            balanceOf[daoWallet] += daoAmount;
            totalSupply -= burnAmount;

            emit Transfer(from, daoWallet, daoAmount);
            emit Transfer(from, address(0), burnAmount);
        }

        balanceOf[from] -= value;
        balanceOf[to] += sendAmount;

        emit Transfer(from, to, sendAmount);
    }

    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
    }

    function setTaxRate(uint256 _taxRate) external onlyOwner {
        require(_taxRate <= 5, "Too high");
        taxRate = _taxRate;
    }

    function setBurnRate(uint256 _burnRate) external onlyOwner {
        require(_burnRate <= 5, "Too high");
        burnRate = _burnRate;
    }

    function setMaxTxLimit(uint256 _maxTxLimit) external onlyOwner {
        maxTxLimit = _maxTxLimit;
    }

    function setMaxWalletLimit(uint256 _maxWalletLimit) external onlyOwner {
        maxWalletLimit = _maxWalletLimit;
    }

    function multiTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool) {
        require(recipients.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            transfer(recipients[i], amounts[i]);
        }
        return true;
    }

    function lockedUntil() public view returns (uint256) {
        return launchTime + 180 days;
    }

    function isLocked() public view returns (bool) {
        return block.timestamp < lockedUntil();
    }

    /**
     * @dev Returns the current circulating supply (excluding burned tokens).
     */
    function circulatingSupply() external view returns (uint256) {
        return totalSupply - balanceOf[address(0)];
    }

    /**
     * @dev Returns the current contract version.
     */
    function version() external pure returns (string memory) {
        return "ver5";
    }
}
