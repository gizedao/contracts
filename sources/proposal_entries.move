module gize::proposal_entries {
    use gize::proposal::{AdminCap, Dao};
    use sui::tx_context::TxContext;
    use gize::proposal;
    use sui::coin::Coin;
    use sui::clock::Clock;

    public entry fun createDao(admin: &AdminCap, ctx: &mut TxContext){
        proposal::createDao(admin, ctx);
    }

    public fun setDaoOperator(admin: &AdminCap, dao: &mut Dao, operatorAddr: address, expireTime: u64, boostFactor: u64, sclock: &Clock, ctx: &mut TxContext){
        proposal::setDaoOperator(admin, dao, operatorAddr, expireTime, boostFactor, sclock, ctx);
    }

    public entry fun setDaoNftBoostConfig<NFT: key + store>(admin: &AdminCap, dao: &mut Dao, boostFactor: u64, threshold: u64, ctx: &mut TxContext){
        proposal::setDaoNftBoostConfig<NFT>(admin, dao, boostFactor, threshold, ctx);
    }

    public entry fun setDaoTokenBoostConfig<TOKEN>(admin: &AdminCap, dao: &mut Dao, boostFactor: u64, threshold: u64, ctx: &mut TxContext){
        proposal::setDaoTokenBoostConfig<TOKEN>(admin, dao, boostFactor, threshold, ctx);
    }


    public entry fun submitProposalByAdmin(_admin: &AdminCap,
                                     name: vector<u8>,
                                     description: vector<u8>,
                                     thread_link: vector<u8>,
                                     type: u8,
                                     anonymous_boost: u64,
                                     nft_boost: u64,
                                     vote_type: u8,
                                     token_condition_threshold: u64,
                                     expire: u64,
                                     dao: &mut Dao,
                                     ctx: &mut TxContext) {
        proposal::submitProposalByAdmin(
            _admin,
            name,
            description,
            thread_link,
            type,
            anonymous_boost,
            nft_boost,
            vote_type,
            token_condition_threshold,
            expire,
            dao,
            ctx
        );
    }

    public entry fun submitProposalOperator(name: vector<u8>,
                                      description: vector<u8>,
                                      thread_link: vector<u8>,
                                      type: u8,
                                      anonymous_boost: u64,
                                      nft_boost: u64,
                                      vote_power_threshold: u64,
                                      vote_type: u8,
                                      expire: u64,
                                      dao: &mut Dao,
                                      sclock: &Clock,
                                      ctx: &mut TxContext)
    {
        proposal::submitProposalByOperator(name, description, thread_link,
            type, anonymous_boost, nft_boost, vote_power_threshold,
            vote_type, expire, dao, sclock, ctx);
    }

    public entry fun submitProposalByToken<TOKEN>(
                                     name: vector<u8>,
                                     description: vector<u8>,
                                     thread_link: vector<u8>,
                                     type: u8,
                                     anonymous_boost: u64,
                                     nft_boost: u64,
                                     vote_power_threshold: u64,
                                     vote_type: u8,
                                     expire: u64,
                                     dao: &mut Dao,
                                     token: &Coin<TOKEN>,
                                     ctx: &mut TxContext) {
        proposal::submitProposalByToken<TOKEN>(
            name,
            description,
            thread_link,
            type,
            anonymous_boost,
            nft_boost,
            vote_power_threshold,
            vote_type,
            expire,
            dao,
            token,
            ctx);
    }

    public entry  fun submitProposalByNfts<NFT: key + store>(name: vector<u8>,
                                                      description: vector<u8>,
                                                      thread_link: vector<u8>,
                                                      type: u8,
                                                      anonymous_boost: u64,
                                                      nft_boost: u64,
                                                      vote_power_threshold: u64,
                                                      vote_type: u8,
                                                      expire: u64,
                                                      dao: &mut Dao,
                                                      nfts: &NFT, //@fixme can we pass this to entry function from SDK ?
                                                      ctx: &mut TxContext) {
        proposal::submitProposalByNfts<NFT>(
            name,
            description,
            thread_link,
            type,
            anonymous_boost,
            nft_boost,
            vote_power_threshold,
            vote_type,
            expire,
            dao,
            nfts,
            ctx);
    }

    public fun addProposalWhitelistToken<TOKEN>(admin: &AdminCap,
                                                propAddr: address,
                                                dao: &mut Dao,
                                                ctx: &mut TxContext) {
        proposal::addProposalWhitelistToken<TOKEN>(admin, propAddr, dao, ctx);
    }

    public fun addProposalWhitelistNft<NFT>(admin: &AdminCap,
                                            propAddr: address,
                                            dao: &mut Dao,
                                            ctx: &mut TxContext) {
        proposal::addProposalWhitelistNft<NFT>(admin, propAddr, dao, ctx);
    }

    public fun voteByToken<TOKEN: key + store>(
        propAddr: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        power: &Coin<TOKEN>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        proposal::voteByToken<TOKEN>(propAddr, dao, choices, choice_values, power, sclock, ctx);
    }

    public fun voteByNft<NFT: key + store>(
        propAddr: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        _nftProof: &NFT,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        proposal::voteByNft<NFT>(propAddr, dao, choices, choice_values, _nftProof, sclock, ctx);
    }

    public fun voteAnonymous(
        propAddr: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        proposal::voteAnonymous(propAddr, dao, choices, choice_values, sclock, ctx);
    }

    public fun unvote(propAddr: address, dao: &mut Dao, sclock: &Clock, ctx: &mut TxContext) {
        proposal::unvote(propAddr, dao, sclock, ctx);
    }

    public fun finalize(_admin: &AdminCap, propAddr: address, dao: &mut Dao, sclock: &Clock, ctx: &mut TxContext) {
        proposal::finalize(_admin, propAddr, dao, sclock, ctx);
    }
}
