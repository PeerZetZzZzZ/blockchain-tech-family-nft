import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity ^0.8.17;

// Fixed supply NFT with random lottery based mint (based onhttps://forum.openzeppelin.com/t/are-nft-projects-doing-starting-index-randomization-and-provenance-wrong-or-is-it-just-me/14147/3)
// Usage:
// 1. create NFT attributes set and deploy to destination (like IPFS)
// 2. create NFT attributes.json with NFT attributes details and calculate sha256 of it. Deploy the file to destination (like IPFS).
// 3. deploy InterviewNft contract providing: max supply, base URI and integrity sha256 hash (calculated in 2.).
//    Integrity hash can be validated any time that it matches the order and content of attributes data IPFS.
// 4. Transfer InterviewNft rights to desired owner (like multi-sig wallet).
// 5. Owner can interact with InterviewNft to mint NFTs for users.
//
// Restrictions:
// - 1 NFT per 1 address
// - transfer NFT only to owner or by owner
//
// Random lottery mint overview:
// - mint process assigns next tokenId to minted NFT (0,1,2,...,maxSupply)
// - first mint generates startingIndex - random number from range 0 - maxSupply
// - calculated tokenURI for tokenId uses startingIndex to generate randomized tokenURI id
// Example:
// - maxSupply: 10
// - generated startingIndex on first mint execution: 4
// - tokenURI id for tokenId 0: (0 + 4) % 10 = 4
// - tokenURI id for tokenId 1: (1 + 4) % 10 = 5
// - tokenURI id for tokenId 2: (2 + 4) % 10 = 6
// - tokenURI id for tokenId 3: (3 + 4) % 10 = 7
// - tokenURI id for tokenId 4: (4 + 4) % 10 = 8
// - tokenURI id for tokenId 5: (5 + 4) % 10 = 9
// - tokenURI id for tokenId 6: (6 + 4) % 10 = 0
// - tokenURI id for tokenId 7: (7 + 4) % 10 = 1
// - tokenURI id for tokenId 8: (8 + 4) % 10 = 2
// - tokenURI id for tokenId 9: (9 + 4) % 10 = 3

// Random lottery mint challange: startingIndex must be as much random as possible :)
// - InterviewNft startingIndex generation is based on block hash obtained during first mint
// - ChailinkVRF could be used to generate appropriate initial random number (https://docs.chain.link/vrf/v2/introduction)
contract BlockchainTechFamilyInterviewNFT is ERC721, Ownable {

    // Max supply of NFTs
    uint256 public maxSupply;
    // Currently supply (how much already mninted)
    uint256 public currentSupply;
    // Properties data endpoint base uri
    string public baseUri;
    // This is used to prove that properties data were unchanged, especially the order
    uint256 public dataIntegrityHash;
    // Internal variable for obtaining user NFT id
    uint256 public startingIndex;
    //
    mapping(address => uint256) private _holders;

    constructor (uint256 maxSupply_, string memory baseUri_, string memory dataIntegrityHash_) ERC721('BlockchainTechFamilyInterviewNFT', 'BTFI')  {
        maxSupply = maxSupply_;
        baseUri = baseUri_;
        dataIntegrityHash = dataIntegrityHash;
    }

    function mint(address mintToAddress) public onlyOwner {
        require(currentSupply < maxSupply, "Max supply already reached");
        require(_holders[msg.sender] == 0, "Single address can have 1 NFT");
        _holders[msg.sender]++;
        uint256 tokenId = currentSupply;
        setStartingIndex();
        currentSupply++;
        _safeMint(mintToAddress, tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        require(_exists(tokenId), "tokenId doesnt exist");

        string memory baseURI = _baseURI();
        string memory sequenceId;
        sequenceId = Strings.toString((tokenId + startingIndex) % maxSupply);
        return string(abi.encodePacked(baseURI, sequenceId));
    }

    function setStartingIndex() private {
        uint256 startingIndexBlock = block.number;
        startingIndex = uint(blockhash(startingIndexBlock)) % maxSupply;
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex + 1;
        }
    }

    function _baseURI() internal view override(ERC721) returns (string memory) {
        return baseUri;
    }

    modifier onlyContractOwnerOrNftOwnerTransferingToContractOwner(address to, uint256 tokenId) {
        require(msg.sender == owner() || (to == owner() && (ERC721.ownerOf(tokenId) == msg.sender)), "Transfer possible only by contract owner or to contract owner by NFT owner");
        _;
    }

    // NFT transfer can be done:
    // - only by contract owner
    // - only to contract owner by current NFT owner
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721) onlyContractOwnerOrNftOwnerTransferingToContractOwner(to, tokenId) {
        _transfer(from, to, tokenId);
        _updateHolders(from, to);
    }

    // NFT transfer can be done:
    // - only by contract owner
    // - only to contract owner by current NFT owner
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override(ERC721) onlyContractOwnerOrNftOwnerTransferingToContractOwner(to, tokenId) {
        _safeTransfer(from, to, tokenId, data);
        _updateHolders(from, to);
    }

    function _updateHolders(address from, address to) private {
        _holders[to]++;
        _holders[from]--;
    }

}