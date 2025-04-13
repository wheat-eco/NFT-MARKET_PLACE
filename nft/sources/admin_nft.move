module nft::admin_nft {

    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::event;
    use std::string;
    use sui::url::{Self, Url};

    /// Represents an NFT
    public struct NFT has key, store {
        id: UID,
        name: string::String,
        description: string::String,
        url: Url,
    }

    /// Represents an NFT Collection
    public struct NFTCollection has key, store {
        id: UID,
        name: string::String,
        description: string::String,
        total_supply: u64,
        minted: u64,
        price: u64, // Price in SUI
    }

    /// Event emitted when an NFT is minted
    public struct NFTMinted has copy, drop, store {
        object_id: ID,
        collection_id: ID, // Use ID instead of UID
        minter: address,
    }

    /// Error codes
    const E_NOT_ADMIN: u64 = 1;
    const E_SUPPLY_EXHAUSTED: u64 = 2;

    /// Admin address (hardcoded for simplicity)
    const ADMIN: address = @0xe44e81950499d6e8b149c2237340bf1048f9646c008379736802fd86db4fb120;

    /// ===== Admin Functions =====

    /// Create a new NFT collection
    public fun create_collection(
        name: vector<u8>,
        description: vector<u8>,
        total_supply: u64,
        price: u64,
        ctx: &mut TxContext,
    ): NFTCollection {
        assert!(ctx.sender() == ADMIN, E_NOT_ADMIN);

        let collection = NFTCollection {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            total_supply,
            minted: 0,
            price,
        };

        // Return the collection
        collection
    }

    /// Delete an NFT collection
    public fun delete_collection(collection: NFTCollection, ctx: &mut TxContext) {
        assert!(ctx.sender() == ADMIN, E_NOT_ADMIN);
        let NFTCollection { id, name: _, description: _, total_supply: _, minted: _, price: _ } = collection;
        id.delete();
    }

    /// Update the price of NFTs in a collection
    public fun update_price(collection: &mut NFTCollection, new_price: u64, ctx: &mut TxContext) {
        assert!(ctx.sender() == ADMIN, E_NOT_ADMIN);
        collection.price = new_price;
    }

    /// ===== User Functions =====

    /// Custom transfer function for NFTs
    public fun transfer_nft(nft: NFT, recipient: address) {
        transfer::transfer(nft, recipient);
    }

    /// Mint an NFT from a collection
    public fun mint_nft(
        collection: &mut NFTCollection,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext,
    ): NFT {
        assert!(collection.minted < collection.total_supply, E_SUPPLY_EXHAUSTED);

        let nft = NFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
        };

        collection.minted = collection.minted + 1;

        event::emit(NFTMinted {
            object_id: object::id(&nft),
            collection_id: object::id(collection), // Use the collection directly
            minter: ctx.sender(),
        });

        // Return the NFT
        nft
    }

    /// Transfer an NFT after minting
    public fun transfer_nft_after_mint(nft: NFT, recipient: address) {
        transfer_nft(nft, recipient);
    }

    /// Get metadata of an NFT
    public fun get_metadata(nft: &NFT): (&string::String, &string::String, &Url) {
        (&nft.name, &nft.description, &nft.url)
    }

    /// ===== View Functions =====

    /// Get the remaining supply of a collection
    public fun remaining_supply(collection: &NFTCollection): u64 {
        collection.total_supply - collection.minted
    }

    /// Get the price of NFTs in a collection
    public fun get_price(collection: &NFTCollection): u64 {
        collection.price
    }

    /// ===== Entry Functions =====

    /// Entry function to create an NFT collection and transfer it to the sender
    public entry fun create_collection_and_transfer(
        name: vector<u8>,
        description: vector<u8>,
        total_supply: u64,
        price: u64,
        ctx: &mut TxContext
    ) {
        let collection = create_collection(name, description, total_supply, price, ctx);
        transfer::transfer(collection, tx_context::sender(ctx));
    }

    /// Entry function to mint an NFT and transfer it to a recipient
    public entry fun mint_nft_and_transfer(
        collection: &mut NFTCollection,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let nft = mint_nft(collection, name, description, url, ctx);
        transfer_nft(nft, recipient);
    }
}