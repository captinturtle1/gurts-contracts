// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IGurts {
  function ownerOf(uint256 tokenId) external returns (address);
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata _data) external;
  function transferFrom(address from, address to, uint256 tokenId) external;
}

contract gurtsStake is Ownable, IERC721Receiver, ReentrancyGuard{
    struct stakedTokenInfo {
        uint256 stakeStarted;
        uint256 stakeTotal;
        address owner;
    }

    event Deposit(address indexed user, uint256[] indexed ids);
    event Withdraw(address indexed user, uint256[] indexed ids);

    mapping(uint256 => stakedTokenInfo) public tokenInfo;
    mapping(address => uint256[]) userTokens;
    IGurts public Gurts = IGurts(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8);
    bool public stakingLaunched;
    bool public depositPaused;



    // public functions

    // stake nft
    function deposit(uint256[] calldata tokenIds) external nonReentrant {
        address _caller = msg.sender;
        require(!depositPaused, "Deposit is paused");
        require(stakingLaunched, "Staking is not live yet");

        require(tokenIds.length > 0, "Must deposit atleast 1");
        require(_caller == tx.origin, "No Contracts");

        for (uint256 i; i < tokenIds.length; i++) {
            require(Gurts.ownerOf(tokenIds[i]) == _caller, "Not owner of token");

            Gurts.safeTransferFrom(_caller, address(this), tokenIds[i], "");
            tokenInfo[tokenIds[i]].stakeStarted = block.timestamp;
            tokenInfo[tokenIds[i]].owner = _caller;
            userTokens[_caller].push(tokenIds[i]);
        }

        emit Deposit(_caller, tokenIds);
    }

    // withdraw staked nfts
    function withdraw(uint256[] calldata tokenIds) external nonReentrant {
        address _caller = msg.sender;
        require(tokenIds.length > 0, "Must withdraw atleast 1");
        require(_caller == tx.origin, "No Contracts");

        for (uint256 i; i < tokenIds.length; i++) {
            address tokenOwner = tokenInfo[tokenIds[i]].owner;
            require(Gurts.ownerOf(tokenIds[i]) == address(this), "Token not staked");
            require(tokenOwner == _caller, "Not staked token holder");

            tokenInfo[tokenIds[i]].stakeTotal += block.timestamp - tokenInfo[tokenIds[i]].stakeStarted;
            tokenInfo[tokenIds[i]].stakeStarted = 0;
            tokenInfo[tokenIds[i]].owner = address(0);
            userTokens[_caller] = shiftToEndOfArray(userTokens[_caller], tokenIds[i]);
            userTokens[_caller].pop();

            Gurts.transferFrom(address(this), tokenOwner, tokenIds[i]);
        }

        emit Withdraw(_caller, tokenIds);
    }    

    // returns owner of currently staked nft, if nots staed will return the 0 address
    function ownerOf(uint256 tokenId) public view returns (address) {
        return tokenInfo[tokenId].owner;
    }

    // returns array of tokens staked by address
    function addressTokens(address _address) public view returns (uint256[] memory) {
        return userTokens[_address];
    }

    // returns current stake time for staked nft. if not staked returns 0
    function currentStakeTime(uint256 tokenId) public view returns (uint256) {
      if (tokenInfo[tokenId].stakeStarted != 0) {
        return block.timestamp - tokenInfo[tokenId].stakeStarted;
      } else {
        return 0;
      }   
    }

    // returns current stake time accross all tokens for an address
    function currentStakeTimeAll(address _address) public view returns (uint256) {
        uint256 allStakeTime;
        for (uint256 i; i < userTokens[_address].length; i++) {
            if (tokenInfo[userTokens[_address][i]].stakeStarted != 0) {
                allStakeTime += block.timestamp - tokenInfo[userTokens[_address][i]].stakeStarted;
            }
        }
        return allStakeTime;
    }

    // returns users stake points (1st token staked adds 100% of time staked, every token after is 50% of time staked)
    function stakePoints(address _address) public view returns (uint256) {
        uint256 currentPoints;
        for (uint256 i; i < userTokens[_address].length; i++) {
            if (tokenInfo[userTokens[_address][i]].stakeStarted != 0) {
                if (i == 0) {
                    currentPoints += block.timestamp - tokenInfo[userTokens[_address][i]].stakeStarted;
                } else {
                    currentPoints += (block.timestamp - tokenInfo[userTokens[_address][i]].stakeStarted) / 2;
                }
            }
        }
        return currentPoints;
    }

    // returns current stake time accross all tokens for an address
    function totalStakeTimeAll(address _address) public view returns (uint256) {
        uint256 allStakeTime;
        for (uint256 i; i < userTokens[_address].length; i++) {
            if (tokenInfo[userTokens[_address][i]].stakeTotal != 0) {
                allStakeTime += tokenInfo[userTokens[_address][i]].stakeTotal;
            }
        }
        return allStakeTime;
    }



    // owner only functions

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
    function onERC721Received(address, address, uint256, bytes calldata) override external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // shift array element to end to remove
    function shiftToEndOfArray(uint256[] memory list, uint256 tokenId) internal pure returns (uint256[] memory) {
        uint256 tokenIndex = 0;
        uint256 lastTokenIndex = list.length - 1;
        uint256 length = list.length;

        for (uint256 i = 0; i < length; i++) {
            if (list[i] == tokenId) {
                tokenIndex = i + 1;
                break;
            }
        }
        require(tokenIndex != 0);

        tokenIndex -= 1;

        if (tokenIndex != lastTokenIndex) {
            list[tokenIndex] = list[lastTokenIndex];
            list[lastTokenIndex] = tokenId;
        }
        return list;
    }
}