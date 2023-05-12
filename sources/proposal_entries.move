module gize::proposal_entries {
    use gize::proposal::{Dao, Proposal};
    use sui::tx_context::TxContext;
    use gize::proposal;
    use sui::coin::Coin;
    use sui::clock::Clock;
    use gize::version::Version;
    use gize::config::AdminCap;

    ///Create DAO by admin
    public entry fun createDao(adminCap: &AdminCap,
                               version: &mut Version,
                               ctx: &mut TxContext){
        proposal::createDao(adminCap, version, ctx);
    }

    public entry fun setThreshold(adminCap: &AdminCap,
                                  operatorThreshold: u64,
                                  snapshotThreshold: u64,
                                  dao: &mut Dao,
                                  version: &mut Version){
        proposal::setThreshold(adminCap, operatorThreshold, snapshotThreshold, dao, version);
    }

    ///Add new DAO operator by admin
    public entry fun setDaoOperator(adminCap: &AdminCap,
                                    operatorAddr: address,
                                    expireTime: u64,
                                    boostFactor: u64,
                                    dao: &mut Dao,
                                    sclock: &Clock,
                                    version: &mut Version){
        proposal::addDaoOperator(adminCap, operatorAddr, expireTime, boostFactor, dao, sclock, version);
    }

    public entry fun setAnonymousBoost(adminCap: &AdminCap,
                                       powerFactor: u64,
                                       dao: &mut Dao,
                                       version: &mut Version){
        proposal::setAnonymousBoost(adminCap,
                                    powerFactor,
                                    dao,
                                    version);
    }

    public entry fun setNftBoost<NFT: key + store>(adminCap: &AdminCap,
                                                   powerFactor: u64,
                                                   dao: &mut Dao,
                                                   version: &mut Version){
        proposal::setNftBoost<NFT>(adminCap,
                                    powerFactor,
                                    dao,
                                    version)
    }


    public entry fun setTokenBoost<TOKEN>(adminCap: &AdminCap,
                                          powerFactor: u64,
                                          dao: &mut Dao,
                                          version: &mut Version){
        proposal::setTokenBoost<TOKEN>(adminCap,
                                        powerFactor,
                                        dao,
                                        version)
    }

    public entry fun snapshotNft<NFT: key + store>(nfts: vector<NFT>,
                                                   dao: &mut Dao,
                                                   version: &mut Version,
                                                   ctx: &mut TxContext){
        proposal::snapshotNft<NFT>(nfts,
                                    dao,
                                    version,
                                    ctx);
    }

    public entry fun unstakeSnapshotNft<NFT: key + store>(dao: &mut Dao,
                                                          version: &mut Version,
                                                          ctx: &mut TxContext){
        proposal::unsnapshotNft<NFT>(dao, version, ctx);
    }

    public entry fun stakeSnapshotToken<TOKEN>(tokens: vector<Coin<TOKEN>>,
                                               dao: &mut Dao,
                                               version: &mut Version,
                                               ctx: &mut TxContext){
        proposal::snapshotToken<TOKEN>(tokens, dao, version, ctx);
    }

    public entry fun unstakeSnapshotToken<TOKEN>(dao: &mut Dao,
                                                 version: &mut Version,
                                                 ctx: &mut TxContext){
        proposal::unsnapshotToken<TOKEN>(dao, version, ctx);
    }

    ///Operator make new proposal
    public entry fun submitProposalOperator(name: vector<u8>,
                                            description: vector<u8>,
                                            threadLink: vector<u8>,
                                            type: u8,
                                            votePowerThreshold: u64,
                                            voteType: u8,
                                            expire: u64,
                                            choiceCodes: vector<u8>,
                                            choiceNames: vector<vector<u8>>,
                                            choiceThresholds: vector<u64>,
                                            dao: &mut Dao,
                                            version: &mut Version,
                                            sclock: &Clock,
                                            ctx: &mut TxContext)
    {
        proposal::submitProposalByOperator(name,
            description,
            threadLink,
            type,
            votePowerThreshold,
            voteType,
            expire,
            choiceCodes,
            choiceNames,
            choiceThresholds,
            dao,
            sclock,
            version,
            ctx);
    }

    ///Sumbit proposal directly using Coin list
    public entry fun submitProposalByToken<TOKEN>(
        name: vector<u8>,
        description: vector<u8>,
        threadLink: vector<u8>,
        type: u8,
        votePowerThreshold: u64,
        voteType: u8,
        expire: u64,
        choiceCodes: vector<u8>,
        choiceNames: vector<vector<u8>>,
        choiceThresholds: vector<u64>,
        dao: &mut Dao,
        token: &Coin<TOKEN>,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext) {
        proposal::submitProposalByToken<TOKEN>(
            name,
            description,
            threadLink,
            type,
            votePowerThreshold,
            voteType,
            expire,
            choiceCodes,
            choiceNames,
            choiceThresholds,
            dao,
            token,
            sclock,
            version,
            ctx);
    }

    ///Sumbit proposal directly using NFT collections
    public entry  fun submitProposalByNfts<NFT: key + store>(name: vector<u8>,
                                                             description: vector<u8>,
                                                             threadLink: vector<u8>,
                                                             type: u8,
                                                             votePowerThreshold: u64,
                                                             voteType: u8,
                                                             expire: u64,
                                                             choiceCodes: vector<u8>,
                                                             choiceNames: vector<vector<u8>>,
                                                             choiceThresholds: vector<u64>,
                                                             dao: &mut Dao,
                                                             nfts: vector<NFT>,
                                                             version: &mut Version,
                                                             sclock: &Clock,
                                                             ctx: &mut TxContext) {
        proposal::submitProposalByNfts<NFT>(
            name,
            description,
            threadLink,
            type,
            votePowerThreshold,
            voteType,
            expire,
            choiceCodes,
            choiceNames,
            choiceThresholds,
            dao,
            sclock,
            nfts,
            version,
            ctx);
    }

    ///Sumbit proposal using staked power
    public entry fun submitProposalByPower(name: vector<u8>,
                                           description: vector<u8>,
                                           threadLink: vector<u8>,
                                           type: u8,
                                           votePowerThreshold: u64,
                                           voteType: u8,
                                           expire: u64,
                                           choiceCodes: vector<u8>,
                                           choiceNames: vector<vector<u8>>,
                                           choiceThresholds: vector<u64>,
                                           dao: &mut Dao,
                                           version: &mut Version,
                                           sclock: &Clock,
                                           ctx: &mut TxContext) {
        proposal::submitProposalByPower(name,
            description,
            threadLink,
            type,
            votePowerThreshold,
            voteType,
            expire,
            choiceCodes,
            choiceNames,
            choiceThresholds,
            dao,
            sclock,
            version,
            ctx)
    }

    /// Delist when proposal in init!
    public entry fun delistProposal(prop: Proposal,
                                    dao: &mut Dao,
                                    version: &mut Version,
                                    ctx: &mut TxContext){
        proposal::delistProposal(prop, dao, version, ctx);
    }


    ///Owner officially start proposal
    public entry fun listProposal(prop: &mut Proposal,
                                  version: &mut Version,
                                  sclock: &Clock,
                                  ctx: &mut TxContext){
        proposal::listProposal(prop, sclock, version, ctx);
    }


    ///VOTING
    ///
    public fun voteBySnapshotPower(prop: &mut Proposal,
                                   dao: &mut Dao,
                                   choices: vector<u8>,
                                   choiceValues: vector<u64>,
                                   powerUsed: u64,
                                   version: &mut Version,
                                   sclock: &Clock,
                                   ctx: &mut TxContext){
        proposal::voteBySnapshotPower(
            prop,
            dao,
            choices,
            choiceValues,
            powerUsed,
            sclock,
            version,
            ctx
        );
    }

    ///User vote using token power
    public entry fun voteByCoin<TOKEN: key + store>(
        prop: &mut Proposal,
        dao: &mut Dao,
        choices: vector<u8>,
        choiceValues: vector<u64>,
        coins: vector<Coin<TOKEN>>,
        powerUsed: u64,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext
    ){
        proposal::voteByCoin<TOKEN>(prop,
            dao,
            choices,
            choiceValues,
            coins,
            powerUsed,
            sclock,
            version,
            ctx);
    }

    ///User vote using NFT power
    public entry fun voteByNft<NFT: key + store>(
        prop: &mut Proposal,
        dao: &mut Dao,
        choices: vector<u8>,
        choiceValues: vector<u64>,
        nfts: vector<NFT>,
        powerUsed: u64,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        proposal::voteByNfts<NFT>(prop,
            dao,
            choices,
            choiceValues,
            nfts,
            powerUsed,
            sclock,
            version,
            ctx);
    }

    ///User unvote
    public entry fun unvote(prop: &mut Proposal,
                            dao: &mut Dao,
                            version: &mut Version,
                            sclock: &Clock,
                            ctx: &mut TxContext) {
        proposal::unvote(prop, dao, sclock, version,ctx);
    }

    ///Owner finalize proposal
    public entry fun finalize(prop: &mut Proposal,
                              dao: &mut Dao,
                              version: &mut Version,
                              sclock: &Clock,
                              ctx: &mut TxContext) {
        proposal::finalize(prop, dao, sclock, version, ctx);
    }
}
