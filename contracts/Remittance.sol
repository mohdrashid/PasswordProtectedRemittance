pragma solidity ^0.4.2;

// This is just a simple example of a coin-like contract.
// It is not standards compatible and cannot be expected to talk to other
// coin/token contracts. If you want to create a standards-compliant
// token, see: https://github.com/ConsenSys/Tokens. Cheers!

contract Remittance {

	address public owner;
	uint public maxDeadline;
	uint public deploymentCost;

	struct Remit{
	address sender;
	uint amount;
	address receiver;
	uint deadline;
	}


	mapping (bytes32 => Remit) ledger;

	event LogTransfer(address _from, address _to, uint256 _value);
	event LogWithdraw(address _from, uint256 _value);
	event LogRefund(address _from, uint256 _value);


	modifier requireOwner(address _owner){
		require(owner == _owner);
		_;
	}

	function Remittance(uint _maxDeadline) {
		owner=msg.sender;
		maxDeadline=_maxDeadline;
		deploymentCost=818352;
	}

	function isKeyUsed(bytes32 password) public constant returns(bool){
		return (ledger[password].amount==0);
	}

	function sendMoney(bytes32 key, address receiver,uint deadline) payable returns(bool sufficient) {
		if (msg.value==0) revert();
		if(block.number+maxDeadline<deadline) revert();
		if(!isKeyUsed(key)){
			//Discounted Rate for transaction fees
			uint transactionCharge=(deploymentCost-1000)*tx.gasprice;
			require((msg.value-transactionCharge)>0);
			require((owner.balance+transactionCharge)<owner.balance);
			owner.transfer(transactionCharge);

			ledger[key]=Remit(msg.sender,msg.value-transactionCharge,receiver,deadline);
			LogTransfer(msg.sender, receiver, msg.value);
			return true;
		}
		return false;
	}

	function withdrawMoney(bytes32 pw1,bytes32 pw2) public returns(bool) {
		bytes32 key=keccak256(pw1,pw2);
		if(ledger[key].amount==0) return false;
		Remit memory record = ledger[key];
		if(record.receiver!=msg.sender) revert();
		uint amount=record.amount;
		if((record.receiver.balance+amount)<record.receiver.balance) revert();
		record.receiver.transfer(amount);
		LogWithdraw(msg.sender, amount);
		ledger[key]=Remit(record.sender,0,msg.sender,record.deadline);
		return true;
	}

	function refund(bytes32 pw1,bytes32 pw2) public returns(bool) {
		bytes32 key=keccak256(pw1,pw2);
		Remit memory record = ledger[key];
		require(msg.sender == record.sender);
		if(record.amount==0) return false;
		if(record.deadline>block.number) return false;
		require((record.sender.balance+record.amount)<record.sender.balance);
		record.sender.transfer(record.amount);
		LogRefund(msg.sender, record.amount);
		ledger[key]=Remit(record.sender,0,msg.sender,record.deadline);
		return true;
	}


	function getBalance(bytes32 pw1,bytes32 pw2) returns(uint) {
		bytes32 key=keccak256(pw1,pw2);
		return ledger[key].amount;
	}

	function setMaxDeadline(uint _maxDeadline) requireOwner(msg.sender) returns(bool){
		maxDeadline=_maxDeadline;
	}

	function kill() requireOwner(msg.sender) returns (bool success) {
		selfdestruct(owner);
		success=true;
	}
}
