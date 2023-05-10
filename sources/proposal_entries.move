module gize::proposal_entries {
    use gize::proposal::{AdminCap, Dao};
    use sui::tx_context::TxContext;
    use gize::proposal;
    use sui::coin::Coin;
    use sui::clock::Clock;

    ///Create DAO by admin
    public entry fun createDao(admin: &AdminCap, ctx: &mut TxContext){
        proposal::createDao(admin, ctx);
    }

    ///Add new DAO operator by admin
    public fun setDaoOperator(admin: &AdminCap, dao: &mut Dao, operatorAddr: address, expireTime: u64, boostFactor: u64, sclock: &Clock, ctx: &mut TxContext){
        proposal::setDaoOperator(admin, dao, operatorAddr, expireTime, boostFactor, sclock, ctx);
    }

    ///Add new NFT type that used to boost operator role
    public entry fun setDaoRoleBoostConfigNft<NFT: key + store>(admin: &AdminCap, dao: &mut Dao, boostFactor: u64, threshold: u64, ctx: &mut TxContext){
        proposal::setDaoRoleBoostConfigNft<NFT>(admin, dao, boostFactor, threshold, ctx);
    }

    ///Add new Token type that used to boost operator role
    public entry fun setDaoRoleBoostConfigToken<TOKEN>(admin: &AdminCap, dao: &mut Dao, boostFactor: u64, threshold: u64, ctx: &mut TxContext){
        proposal::setDaoRoleBoostConfigToken<TOKEN>(admin, dao, boostFactor, threshold, ctx);
    }

    ///Admin make new proposal
    public entry fun submitProposalByAdmin(adminCap: &AdminCap,
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
                                           sclock: &Clock,
                                           ctx: &mut TxContext) {
        proposal::submitProposalByAdmin(
            adminCap,
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
            sclock,
            ctx
        );
    }

    ///Operator make new proposal
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

    ///Boosted user using Token to make new proposal
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
                                     sclock: &Clock,
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
            sclock,
            ctx);
    }

    ///Boosted user using NFT collection to make new proposal
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
                                                      nfts: vector<NFT>,
                                                      sclock: &Clock,
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
            sclock,
            nfts,
            ctx);
    }

    ///Owner officially start proposal
    public entry fun listProposal(proposalId: address,
                            dao: &mut Dao,
                            sclock: &Clock,
                            ctx: &mut TxContext){
        proposal::listProposal(proposalId, dao, sclock, ctx);

    }

    public entry fun delistProposal(proposalId: address,
                              dao: &mut Dao,
                              ctx: &mut TxContext){
        proposal::delistProposal(proposalId, dao, ctx);

    }
    ///Add new token type to whitelist used to boost voting power
    public entry fun addProposalVoteBoostWhitelistToken<TOKEN>(proposalId: address,
                                                               dao: &mut Dao,
                                                               ctx: &mut TxContext) {
        proposal::addProposalWhitelistToken<TOKEN>(proposalId, dao, ctx);
    }

    ///Add new NFT type to whitelist used to boost voting power
    public entry fun addProposalVoteBoostWhitelistNft<NFT>(proposalId: address,
                                                           dao: &mut Dao,
                                                           ctx: &mut TxContext) {
        proposal::addProposalWhitelistNft<NFT>(proposalId, dao, ctx);
    }

    ///User vote using token power
    public entry fun voteByToken<TOKEN: key + store>(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        power: &Coin<TOKEN>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        proposal::voteByToken<TOKEN>(proposalId, dao, choices, choice_values, power, sclock, ctx);
    }

    ///User vote using NFT power
    public entry fun voteByNft<NFT: key + store>(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        nfts: vector<NFT>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        proposal::voteByNfts<NFT>(proposalId, dao, choices, choice_values, nfts, sclock, ctx);
    }

    ///Anonymous user vote
    public entry fun voteAnonymous(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        proposal::voteAnonymous(proposalId, dao, choices, choice_values, sclock, ctx);
    }

    ///User unvote
    public entry fun unvote(proposalId: address, dao: &mut Dao, sclock: &Clock, ctx: &mut TxContext) {
        proposal::unvote(proposalId, dao, sclock, ctx);
    }

    ///Admin finalize proposal
    public entry fun finalize(_admin: &AdminCap, proposalId: address, dao: &mut Dao, sclock: &Clock, ctx: &mut TxContext) {
        proposal::finalize(_admin, proposalId, dao, sclock, ctx);
    }
}
