// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IGurts {
  function ownerOf(uint256 tokenId) external returns (address);
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata _data) external;
  function transferFrom(address from, address to, uint256 tokenId) external;
}

contract gurtsStake is Ownable, IERC721Receiver{
    struct stakedTokenInfo {
        uint256 stakeStarted;
        uint256 stakeTotal;
        address owner;
    }

    event Deposit(address indexed user, uint256[] indexed ids);
    event Withdraw(address indexed user, uint256[] indexed ids);

    mapping(uint256 => stakedTokenInfo) public tokenInfo;
    mapping(address => uint256) public balanceOf;
    IGurts public Gurts = IGurts(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8);
    bool public stakingLaunched;
    bool public depositPaused;



    // public functions

    // stake nft
    function deposit(uint256[] calldata tokenIds) external {
        address _caller = _msgSender();
        require(!depositPaused, "Deposit is paused");
        require(stakingLaunched, "Staking is not live yet");

        for (uint256 i; i < tokenIds.length; i++) {
            Gurts.safeTransferFrom(_caller, address(this), tokenIds[i], "");
            tokenInfo[tokenIds[i]].stakeStarted = block.timestamp;
            tokenInfo[tokenIds[i]].owner = _caller;
            stakedBalanceOf[_caller] = stakedBalanceOf[_caller] + 1;
        }
        emit Deposit(_caller, tokenIds);
    }

    // withdraw staked nfts
    function withdraw(uint256[] calldata tokenIds) public {
        address _caller = _msgSender();
        for (uint256 i; i < tokenIds.length; i++) {
            require(Gurts.ownerOf(tokenIds[i]) == address(this), "Token not staked");

            tokenInfo[tokenIds[i]].stakeTotal += block.timestamp - tokenInfo[tokenIds[i]].stakeStarted;
            tokenInfo[tokenIds[i]].stakeStarted = 0;
            tokenInfo[tokenIds[i]].owner = address(0);
            stakedBalanceOf[_caller] = stakedBalanceOf[_caller] - 1;

            Gurts.transferFrom(address(this), _caller, tokenIds[i]);
        }
        emit Withdraw(_caller, tokenIds);
    }    

    // returns owner of currently staked nft, if nots staed will return the 0 address
    function ownerOf(uint256 tokenId) public view returns (address) {
        return tokenInfo[tokenId].owner;
    }

    // returns current stake time for staked nft. if not staked returns 0
    function currentStakeTime(uint256 tokenId) public view returns (uint256) {
      if (tokenInfo[tokenId].stakeStarted != 0) {
        return block.timestamp - tokenInfo[tokenId].stakeStarted;
      } else {
        return 0;
      }   
    }



    // owner only functions

    // just incase nft gets stuck somehow, nft will be sent to owner of nft and deposits will be paused to fix any issues
    function unstuckStakedNfts(uint256[] calldata tokenIds) external onlyOwner {
        depositPaused = true;
        for (uint256 i; i < tokenIds.length; i++) {
            stakedTokenInfo memory currentTokenInfo = tokenInfo[tokenIds[i]];
            address receiver = currentTokenInfo.owner;
            if (receiver != address(0) && Gurts.ownerOf(tokenIds[i]) == address(this)) {
                tokenInfo[tokenIds[i]].stakeTotal += block.timestamp - tokenInfo[tokenIds[i]].stakeStarted;
                tokenInfo[tokenIds[i]].stakeStarted = 0;
                tokenInfo[tokenIds[i]].owner = address(0);
                stakedBalanceOf[receiver] = stakedBalanceOf[receiver] - 1;

                Gurts.transferFrom(address(this), receiver, tokenIds[i]);
            }
        }
    }

    // toggles deposits, withdrawals are always open
    function toggleDeposits() public onlyOwner {
        depositPaused = !depositPaused;
    }

    // starts staking, one time function
    function startStaking() public onlyOwner {
        require(!stakingLaunched, "Staking has been launched already");
        stakingLaunched = true;
    }


    // misc functions

    // needed to recieve erc721 nfts
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}