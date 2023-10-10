// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ERC20 {
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function balanceOf(address _owner) external view returns (uint256);
}

interface ERC4626 {
    function balanceOf(address _account) external view returns (uint256);
}

contract VyperVault {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string constant NAME = "Test Vault";
    string constant SYMBOL = "vTEST";
    uint8 constant DECIMALS = 18;

    event Transfer(address indexed _sender, address indexed _receiver, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _allowance);

    ERC20 public asset;

    event Deposit(address indexed _depositor, address indexed _receiver, uint256 _assets, uint256 _shares);
    event Withdraw(
        address indexed _withdrawer, address indexed _receiver, address indexed _owner, uint256 _assets, uint256 _shares
    );

    constructor(ERC20 _asset) {
        asset = _asset;
    }

    function name() external pure returns (string memory) {
        return NAME;
    }

    function symbol() external pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    function transfer(address _receiver, uint256 _amount) external returns (bool) {
        balanceOf[msg.sender] -= _amount;
        balanceOf[_receiver] += _amount;
        emit Transfer(msg.sender, _receiver, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        allowance[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _receiver, uint256 _amount) external returns (bool) {
        allowance[_sender][msg.sender] -= _amount;
        balanceOf[_sender] -= _amount;
        balanceOf[_receiver] += _amount;
        emit Transfer(_sender, _receiver, _amount);
        return true;
    }

    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function _convertToAssets(uint256 _shareAmount) internal view returns (uint256) {
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            return 0;
        }
        return (_shareAmount * asset.balanceOf(address(this))) / _totalSupply;
    }

    function convertToAssets(uint256 _shareAmount) external view returns (uint256) {
        return _convertToAssets(_shareAmount);
    }

    function _convertToShares(uint256 _assetAmount) internal view returns (uint256) {
        uint256 _totalSupply = totalSupply;
        uint256 _totalAssets = asset.balanceOf(address(this));
        if (_totalAssets == 0 || _totalSupply == 0) {
            return _assetAmount;
        }
        return (_assetAmount * _totalSupply) / _totalAssets;
    }

    function convertToShares(uint256 _assetAmount) external view returns (uint256) {
        return _convertToShares(_assetAmount);
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewDeposit(uint256 _assets) external view returns (uint256) {
        return _convertToShares(_assets);
    }

    function deposit(uint256 _assets, address _receiver) external returns (uint256) {
        uint256 shares = _convertToShares(_assets);
        asset.transferFrom(msg.sender, address(this), _assets);
        totalSupply += shares;
        balanceOf[_receiver] += shares;
        emit Deposit(msg.sender, _receiver, _assets, shares);
        return shares;
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewMint(uint256 _shares) external view returns (uint256) {
        uint256 assets = _convertToAssets(_shares);
        if (assets == 0 && asset.balanceOf(address(this)) == 0) {
            return _shares;
        }
        return assets;
    }

    function mint(uint256 _shares, address _receiver) external returns (uint256) {
        uint256 assets = _convertToAssets(_shares);
        if (assets == 0 && asset.balanceOf(address(this)) == 0) {
            assets = _shares;
        }
        asset.transferFrom(msg.sender, address(this), assets);
        totalSupply += _shares;
        balanceOf[_receiver] += _shares;
        emit Deposit(msg.sender, _receiver, assets, _shares);
        return assets;
    }

    function maxWithdraw(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewWithdraw(uint256 _assets) external view returns (uint256) {
        uint256 shares = _convertToShares(_assets);
        if (shares == _assets && totalSupply == 0) {
            return 0;
        }
        return shares;
    }

    function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256) {
        uint256 shares = _convertToShares(_assets);
        if (shares == _assets && totalSupply == 0) {
            revert("Nothing to redeem");
        }
        if (_owner != msg.sender) {
            allowance[_owner][msg.sender] -= shares;
        }
        totalSupply -= shares;
        balanceOf[_owner] -= shares;
        asset.transfer(_receiver, _assets);
        emit Withdraw(msg.sender, _receiver, _owner, _assets, shares);
        return shares;
    }

    function maxRedeem(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewRedeem(uint256 _shares) external view returns (uint256) {
        return _convertToAssets(_shares);
    }

    function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256) {
        if (_owner != msg.sender) {
            allowance[_owner][msg.sender] -= _shares;
        }
        uint256 assets = _convertToAssets(_shares);
        totalSupply -= _shares;
        balanceOf[_owner] -= _shares;
        asset.transfer(_receiver, assets);
        emit Withdraw(msg.sender, _receiver, _owner, assets, _shares);
        return assets;
    }

    function DEBUG_steal_tokens(uint256 _amount) external {
        asset.transfer(msg.sender, _amount);
    }
}
