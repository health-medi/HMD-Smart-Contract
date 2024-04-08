// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HMEDERC20Token is ERC20, ERC20Burnable, Pausable, Ownable(msg.sender) {
    struct LockInfo {
        uint256 amount;
        uint256 releaseTime;
    }

    uint8 constant private _decimals = 18;
    uint256 constant private _initial_supply = 10_000_000_000;

    mapping(address => bool) private frozenAccounts;
    mapping(address => LockInfo[]) private _locks;

    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);
    // event Locked(address indexed account, uint256 amount, uint256 releaseTime);
    event LockReleased(address indexed account, uint256 amount);

    // HEALTHMEDI_V7, HMED7
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, _initial_supply * (10**uint256(_decimals)));
    }

    function _update(address from, address to, uint256 amount) internal override {

        // 발행 및 소각 시에는 잠금 상태를 확인할 필요가 없습니다.
        if(from != address(0) && to != address(0)) {
            require(!paused() || msg.sender == owner(), "Token transfer while paused");

            // 잠금 상태 확인 로직 추가
            require(_checkLock(from, amount), "ERC20Lockable: transfer amount exceeds unlocked balance");
        }
        
        super._update(from, to, amount);
    }

    function freeze(address account) public onlyOwner {
        require(!frozenAccounts[account], "Account is already frozen");
        frozenAccounts[account] = true;
        emit AccountFrozen(account);
    }

    function unfreeze(address account) public onlyOwner {
        require(frozenAccounts[account], "Account is not frozen");
        frozenAccounts[account] = false;
        emit AccountUnfrozen(account);
    }

    function lockup(address account, uint256 amount, uint256 releaseTime) public onlyOwner {
        require(balanceOf(account) >= amount, "Insufficient balance");
        _locks[account].push(LockInfo(amount, releaseTime));
    }

    function releaseLock(address account) public {
        uint256 releasableAmount = 0;
        for (uint256 i = 0; i < _locks[account].length; i++) {
            if (_locks[account][i].releaseTime <= block.timestamp) {
                releasableAmount += _locks[account][i].amount;
                _locks[account][i] = _locks[account][_locks[account].length - 1];
                _locks[account].pop();
                i--;
            }
        }
        if (releasableAmount > 0) {
            emit LockReleased(account, releasableAmount);
        }
    }

    function transferWithLockUp(address recipient, uint256 amount, uint256 lockTime) public onlyOwner {
        _transfer(msg.sender, recipient, amount);
        lockup(recipient, amount, block.timestamp + lockTime);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _checkLock(address from, uint256 amount) private view returns (bool) {
        uint256 lockedAmount = 0;
        // 현재 시간 기준으로 잠금 해제되지 않은 토큰의 총량 계산
        for (uint256 i = 0; i < _locks[from].length; i++) {
            if (_locks[from][i].releaseTime > block.timestamp) {
                lockedAmount += _locks[from][i].amount;
            }
        }
        // 잠금 해제된 토큰의 양이 전송하려는 양보다 크거나 같은지 확인
        return balanceOf(from) - lockedAmount >= amount;
    }

    function getLockedAmount(address account) public view returns (uint256) {
        uint256 lockedAmount = 0;
        for (uint256 i = 0; i < _locks[account].length; i++) {
            if (_locks[account][i].releaseTime > block.timestamp) {
                lockedAmount += _locks[account][i].amount;
            }
        }
        return lockedAmount;
    }
}