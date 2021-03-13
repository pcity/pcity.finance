/**
 *Submitted for verification at BscScan.com on 2021-03-06
*/

pragma solidity ^0.5.17;

interface Callable {
	function tokenCallback(address _from, uint256 _tokens, bytes calldata _data) external returns (bool);
}

// Official Pcity smart contract

contract Pcity{
    
//public variables
    
    string constant public name = "Pcity";
    string constant public symbol = "PCY";
    uint constant public decimals = 18;
    
//private variables 
    
    uint256 constant private MIN_AMOUNT_YOU_CAN_STAKE = 1000;
    uint256 constant private BURNING = 8;
    uint256 constant private DEFAULT_SCALAR_VALUE = 2**64;
    uint256 constant private START_SUPPLY = 8e25;
    uint256 constant private MINIMUM_PERC_SUPPLY = 5;
   
    
    
//Events
    
     // Amount that will be burned after a transfer to one address
    event Flush(uint256 amountCoins);
    event Transfer(address indexed sender, address indexed receiver, uint256 amountCoins);
    event Approval(address indexed participant, address indexed spender, uint256 tokens);
    event FlushingDisabled(address indexed user, bool status);
    
    event Stake(address indexed participant, uint256 amountCoins);
    event Unstake(address indexed participant, uint256 amountCoins);
    event Fetch(address indexed participant, uint256 amountCoins);
   


//Structs
    struct Participants {
        uint256 balance;
        uint256 amountStaked;
        mapping(address => uint256) allowance;
        int256 scaledPayout;
    }

    struct Statistics {
        address adminAddress;
        uint256 totalSupply;
        uint256 totalStaked;
        mapping(address => Participants) participants;
        uint256 scaledPayout;
    }

    Statistics private statistics;

// constructor
    


    constructor() public{
        statistics.adminAddress = msg.sender;
        statistics.totalSupply = START_SUPPLY;
        statistics.participants[msg.sender].balance = START_SUPPLY;
        emit Transfer(address(0x0), msg.sender, START_SUPPLY);
    }
    
// private functions
    
    
function _transfer(address _sender, address _receiver, uint256 _amountCoins) internal returns (uint256){
        require(balanceOf(_sender) >= _amountCoins);
        statistics.participants[_sender].balance -= _amountCoins;
        uint256 _amountFlushed = _amountCoins * BURNING / 100;

        if(totalSupply() - _amountFlushed < START_SUPPLY * MINIMUM_PERC_SUPPLY / 100 ){
            _amountFlushed = 0;
        }

        uint256 _transferring = _amountCoins - _amountFlushed;
        statistics.participants[_receiver].balance += _transferring;

        emit Transfer(_sender, address(this), _amountCoins);
        if (_amountFlushed > 0) {
			if (statistics.totalStaked > 0) {
				_amountFlushed /= 2;
				statistics.scaledPayout += _amountFlushed * DEFAULT_SCALAR_VALUE / statistics.totalStaked;
				emit Transfer(_sender, address(this), _amountFlushed);
			}

			statistics.totalSupply -= _amountFlushed;
			emit Transfer(_sender, address(0x0), _amountFlushed);
			emit Flush(_amountFlushed);
		}

		return _transferring;

    }
    

function _stakePcity(uint256 _amountCoins) internal {
        require(balanceOf(msg.sender) >= _amountCoins);
        require(getStaker(msg.sender) + _amountCoins >= MIN_AMOUNT_YOU_CAN_STAKE);
        statistics.totalStaked += _amountCoins;
        statistics.participants[msg.sender].amountStaked += _amountCoins;
        statistics.participants[msg.sender].scaledPayout += int256(_amountCoins * statistics.scaledPayout);
        emit Transfer(msg.sender, address(this), _amountCoins);
        emit Stake(msg.sender, _amountCoins);
    }

    function _unstakePcity(uint256 _amountCoins) internal {
		require(getStaker(msg.sender) >= _amountCoins);
		uint256 _amountFlushed = _amountCoins * BURNING / 100;
		statistics.scaledPayout += _amountFlushed * DEFAULT_SCALAR_VALUE / statistics.totalStaked;
		statistics.totalStaked -= _amountCoins;
		statistics.participants[msg.sender].balance -= _amountFlushed;
		statistics.participants[msg.sender].amountStaked -= _amountCoins;
		statistics.participants[msg.sender].scaledPayout -= int256(_amountCoins * statistics.scaledPayout);
		emit Transfer(address(this), msg.sender, _amountCoins - _amountFlushed);
		emit Unstake(msg.sender, _amountCoins);
	}

//GET 
    
     function balanceOf(address _participant) public view returns (uint256){
        return statistics.participants[_participant].balance - getStaker(_participant);
    }

    function getStaker(address _participant) public view returns (uint256){
        return statistics.participants[_participant].amountStaked;
    }
    
    function totalSupply() public view returns (uint256){
        return statistics.totalSupply;
    }

    function totalStaked() public view returns (uint256){
        return statistics.totalStaked;
    }
    
    function allowance(address _participant, address _spender) public view returns (uint256) {
		return statistics.participants[_participant].allowance[_spender];
	}

    function getRewards(address _participant) public view returns (uint256){
        return uint256(int256(statistics.scaledPayout * statistics.participants[_participant].amountStaked) - statistics.participants[_participant].scaledPayout) / DEFAULT_SCALAR_VALUE;
    }

    function getData(address _participant)public view returns (uint256 totalSupplyParticipant, uint256 totalStakedParticipant, uint256 balanceParticipant, uint256 stakedParticipant, uint256 rewardsParticipant){
        return (totalSupply(), totalStaked(), balanceOf(_participant), getStaker(_participant), getRewards(_participant));
    }

//Public functions

    function flush(uint256 _coins) external {
        require(balanceOf(msg.sender) >= _coins);
        statistics.participants[msg.sender].balance -= _coins;
        uint256 _amountFlushed = _coins;
        if(statistics.totalStaked > 0){
            _amountFlushed /= 2;
            statistics.scaledPayout += _amountFlushed * DEFAULT_SCALAR_VALUE / statistics.totalStaked;
            emit Transfer(msg.sender, address(this), _amountFlushed);

        }

        statistics.totalSupply -= _amountFlushed;
        emit Transfer(msg.sender, address(0x0), _amountFlushed);
        emit Flush(_amountFlushed);
    }

    function stakePcity(uint256 _amountCoins) external {
        _stakePcity(_amountCoins);
    }

    function unstakePcity(uint256 _amountCoins) external {
		_unstakePcity(_amountCoins);
	}

    function approve(address _spender, uint256 _amountCoins) external returns (bool){
        statistics.participants[msg.sender].allowance[_spender] = _amountCoins;
        emit Approval(msg.sender, _spender, _amountCoins);
        return true;
    }

    

    function bulkTransfer(address[] calldata _receivers, uint256[] calldata _amountCoins) external{
        require(_receivers.length == _amountCoins.length);
        for (uint256 i = 0; i < _receivers.length; i++) {
			_transfer(msg.sender, _receivers[i], _amountCoins[i]);
		}
    }

    function transferFrom(address _sender, address _receiver, uint256 _amountCoins) external returns (bool) {
		require(statistics.participants[_sender].allowance[msg.sender] >= _amountCoins);
		statistics.participants[_sender].allowance[msg.sender] -= _amountCoins;
		_transfer(_sender, _receiver, _amountCoins);
		return true;
	}

	function transfer(address _receiver, uint256 _amountCoins) external returns (bool) {
		_transfer(msg.sender, _receiver, _amountCoins);
		return true;
	}

    function transferPlusReceiveData(address _receiver, uint256 _amountCoins, bytes calldata _data) external returns (bool){
        uint256 _transferring = _transfer(msg.sender, _receiver, _amountCoins);
        uint32 _size;
        assembly {
            _size := extcodesize(_receiver)
        }
        if(_size > 0){
            require(Callable(_receiver).tokenCallback(msg.sender, _transferring, _data));
        }
        return true;
    }

    function allocate(uint256 _amountCoins) external{
        require(statistics.totalStaked > 0);
        require(balanceOf(msg.sender) >= _amountCoins);
        statistics.participants[msg.sender].balance -= _amountCoins;
        statistics.scaledPayout += _amountCoins * DEFAULT_SCALAR_VALUE / statistics.totalStaked;
        emit Transfer(msg.sender,address(this), _amountCoins);
        
    }
    
    function fetch() external returns (uint256) {
		uint256 _participantsWhoCanClaimRewards = getRewards(msg.sender);
		require(_participantsWhoCanClaimRewards >= 0);
		statistics.participants[msg.sender].scaledPayout += int256(_participantsWhoCanClaimRewards * DEFAULT_SCALAR_VALUE);
		statistics.participants[msg.sender].balance += _participantsWhoCanClaimRewards;
		emit Transfer(address(this), msg.sender, _participantsWhoCanClaimRewards);
		emit Fetch(msg.sender, _participantsWhoCanClaimRewards);
		return _participantsWhoCanClaimRewards;
	}
    
 
   
}