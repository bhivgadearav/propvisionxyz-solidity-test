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

    uint256 private constant POINT_MULTIPLIER = 10 ** 18;
    uint256 private magnifiedDividendPerShare;

    mapping(address => int256) private magnifiedDividendCorrections;
    mapping(address => uint256) private withdrawnDividends;

    mapping(address => bool) public participant;
    mapping(address => uint256) private holderIndex;
    address[] private tokenHolders;

    mapping(address => mapping(address => uint256)) private allowances;
    uint256 public dividends;

    function _addHolder(address account) internal {
        if (!participant[account]) {
            participant[account] = true;
            tokenHolders.push(account);
            holderIndex[account] = tokenHolders.length;
        }
    }

    function _removeHolder(address account) internal {
        if (balanceOf[account] == 0 && participant[account]) {
            uint256 idx = holderIndex[account];
            if (idx > 0) {
                address lastHolder = tokenHolders[tokenHolders.length - 1];
                tokenHolders[idx - 1] = lastHolder;
                holderIndex[lastHolder] = idx;

                tokenHolders.pop();
                holderIndex[account] = 0;
                participant[account] = false;
            }
        }
    }

    // --- IERC20 Implementation ---

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

        magnifiedDividendCorrections[msg.sender] += int256(
            value.mul(magnifiedDividendPerShare)
        );
        magnifiedDividendCorrections[to] -= int256(
            value.mul(magnifiedDividendPerShare)
        );

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        if (value > 0) {
            _addHolder(to);
            _removeHolder(msg.sender);
        }

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

        magnifiedDividendCorrections[msg.sender] += int256(
            value.mul(magnifiedDividendPerShare)
        );
        magnifiedDividendCorrections[to] -= int256(
            value.mul(magnifiedDividendPerShare)
        );

        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);

        if (value > 0) {
            _addHolder(to);
            _removeHolder(from);
        }

        return true;
    }

    // --- IMintableToken Implementation ---

    function mint() external payable override {
        require(msg.value > 0, "Invalid value");

        if (totalSupply > 0) {
            magnifiedDividendCorrections[msg.sender] -= int256(
                msg.value.mul(magnifiedDividendPerShare)
            );
        }

        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);

        _addHolder(msg.sender);
    }

    function burn(address payable dest) external override {
        uint256 balance = balanceOf[msg.sender];
        require(balance > 0, "No tokens to burn");

        magnifiedDividendCorrections[msg.sender] += int256(
            balance.mul(magnifiedDividendPerShare)
        );

        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(balance);

        _removeHolder(msg.sender);

        (bool sent, ) = dest.call{value: balance}("");
        require(sent, "Failed to send ETH");
    }

    // --- IDividends Implementation ---

    function getNumTokenHolders() external view override returns (uint256) {
        return tokenHolders.length;
    }

    function getTokenHolder(
        uint256 index
    ) external view override returns (address) {
        return tokenHolders[index.sub(1)];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "Invalid value");
        require(totalSupply > 0, "Total supply is zero");

        dividends = dividends.add(msg.value);
        magnifiedDividendPerShare = magnifiedDividendPerShare.add(
            msg.value.mul(POINT_MULTIPLIER).div(totalSupply)
        );
    }

    function getWithdrawableDividend(
        address payee
    ) public view override returns (uint256) {
        return accumulativeDividendOf(payee).sub(withdrawnDividends[payee]);
    }

    function withdrawDividend(address payable dest) external override {
        uint256 withdrawable = getWithdrawableDividend(msg.sender);
        require(withdrawable > 0, "No dividends to withdraw");

        withdrawnDividends[msg.sender] = withdrawnDividends[msg.sender].add(
            withdrawable
        );

        (bool sent, ) = dest.call{value: withdrawable}("");
        require(sent, "Failed to send ETH");
    }

    function accumulativeDividendOf(
        address payee
    ) public view returns (uint256) {
        int256 magnifiedDividend = int256(
            balanceOf[payee].mul(magnifiedDividendPerShare)
        );
        int256 correctedDividend = magnifiedDividend +
            magnifiedDividendCorrections[payee];
        if (correctedDividend < 0) return 0;
        return uint256(correctedDividend).div(POINT_MULTIPLIER);
    }
}
