pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    // ------------------------------------------ //
    // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
    // ------------------------------------------ //
    using SafeMath for uint256;
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;

    // ------------------------------------------ //
    // ----- END: DO NOT EDIT THIS SECTION ------ //
    // ------------------------------------------ //

    mapping(address => bool) public participant;
    mapping(address => uint256) public index;
    address[] public tokenHolders;
    mapping(address account => mapping(address spender => uint256))
        private allowances;
    uint256 public dividends;

    // IERC20

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return allowances[owner][spender];
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        if (!participant[to]) {
            tokenHolders.push(to);
            index[to] = tokenHolders.length - 1;
            participant[to] = true;
        }
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
        if (balanceOf[msg.sender] == 0) {
            uint256 index = index[msg.sender];
            delete tokenHolders[index];
        }
        balanceOf[to] = balanceOf[to].add(value);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        allowances[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(
            allowances[from][msg.sender] >= value,
            "Insufficient allowance"
        );
        if (!participant[to]) {
            tokenHolders.push(to);
            index[to] = tokenHolders.length - 1;
            participant[to] = true;
        }
        balanceOf[from] = balanceOf[from].sub(value);
        if (balanceOf[from] == 0) {
            uint256 index = index[from];
            delete tokenHolders[index];
        }
        balanceOf[to] = balanceOf[to].add(value);
        allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
        return true;
    }

    // IMintableToken

    function mint() external payable override {
        require(msg.value > 0, "Invalid value");
        if (!participant[msg.sender]) {
            tokenHolders.push(msg.sender);
            index[msg.sender] = tokenHolders.length - 1;
        }
        participant[msg.sender] = true;
        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);
    }

    function burn(address payable dest) external override {
        uint256 index = index[msg.sender];
        delete tokenHolders[index];
        uint256 balance = balanceOf[msg.sender];
        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(balance);
        (bool sent, ) = dest.call{value: balance}("");
        require(sent, "Failed to send ETH");
    }

    // IDividends

    function getNumTokenHolders() external view override returns (uint256) {
        return tokenHolders.length;
    }

    function getTokenHolder(
        uint256 index
    ) external view override returns (address) {
        return tokenHolders[index];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "Invalid value");
        dividends = dividends.add(msg.value);
    }

    function getWithdrawableDividend(
        address payee
    ) external view override returns (uint256) {
        uint256 balance = balanceOf[payee];
        uint256 totalEth = dividends;
        uint256 ethValue = totalEth.div(totalSupply);
        return balance.mul(ethValue);
    }

    function withdrawDividend(address payable dest) external override {
        require(balanceOf[msg.sender] > 0, "Insufficient balance");
        uint256 tokenValue = dividends.div(totalSupply);
        uint256 withdrawableDividend = balanceOf[msg.sender].mul(tokenValue);
        (bool sent, ) = dest.call{value: withdrawableDividend}("");
        require(sent, "Failed to send ETH");
        dividends = dividends.sub(withdrawableDividend);
    }
}
