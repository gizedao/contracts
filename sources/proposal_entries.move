module gize::proposal_entries {
    use gize::proposal::{AdminCap, Dao, OperatorCap, TokenBoostCap, ProposalCap};
    use sui::tx_context::TxContext;
    use gize::proposal;
    use sui::coin::Coin;
    use sui::clock::Clock;

    public fun submitProposalByAdmin(_admin: &AdminCap,
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

    public fun submitProposalOperator(_admin: &OperatorCap,
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
                                      ctx: &mut TxContext)
    {
        proposal::submitProposalByOperator(_admin, name, description, thread_link,
            type, anonymous_boost, nft_boost, vote_power_threshold,
            vote_type, expire, dao, ctx);
    }

    public fun submitProposal(propCap: &ProposalCap,
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
                                        ctx: &mut TxContext) {
        proposal::submitProposal(propCap, name, description, thread_link,
            type, anonymous_boost, nft_boost, vote_power_threshold,
            vote_type, expire, dao, ctx);
    }

    public fun exchangeNftToCap<NFT: key + store>(nft: &NFT, ctx: &mut TxContext) {
        proposal::exchangeNftToCap<NFT>(nft, ctx);
    }

    public fun exchangeTokenToCap<TOKEN: key + store>(token: &Coin<TOKEN>, ctx: &mut TxContext) {
        proposal::exchangeTokenToCap<TOKEN>(token, ctx);
    }

    public fun submitProposalByTokenCap(_tokenCap: &TokenBoostCap,
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
                                        ctx: &mut TxContext) {
        proposal::submitProposalByTokenCap(_tokenCap,
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
