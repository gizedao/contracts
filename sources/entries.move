module gize::entries {
    use gize::proposal::Dao;
    use sui::tx_context::TxContext;
    use gize::proposal;
    use sui::coin::Coin;
    use sui::clock::Clock;
    use gize::version::Version;
    use gize::snapshot::DaoSnapshotConfig;
    use gize::snapshot;
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
                                  daoConfig: &mut DaoSnapshotConfig,
                                  version: &mut Version,
                                  _ctx: &mut TxContext){
        snapshot::setThreshold(adminCap, operatorThreshold, snapshotThreshold, daoConfig, version, _ctx);
    }

    ///Add new DAO operator by admin
    public entry fun setDaoOperator(adminCap: &AdminCap,
                                    operatorAddr: address,
                                    expireTime: u64,
                                    boostFactor: u64,
                                    daoConfig: &mut DaoSnapshotConfig,
                                    sclock: &Clock,
                                    version: &mut Version,
                                    ctx: &mut TxContext){
        snapshot::addDaoOperator(adminCap, operatorAddr, expireTime, boostFactor, daoConfig, sclock, version, ctx);
    }

    public entry fun setAnonymousBoost(adminCap: &AdminCap,
                                       powerFactor: u64,
                                       configReg: &mut DaoSnapshotConfig,
                                       version: &mut Version,
                                       ctx: &mut TxContext){
        snapshot::setAnonymousBoost(adminCap,
                                    powerFactor,
                                    configReg,
                                    version,
                                    ctx);
    }

    public entry fun setNftBoost<NFT: key + store>(adminCap: &AdminCap,
                                                   powerFactor: u64,
                                                   configReg: &mut DaoSnapshotConfig,
                                                   version: &mut Version,
                                                   ctx: &mut TxContext){
        snapshot::setNftBoost<NFT>(adminCap,
            powerFactor,
                                            configReg,
                                            version,
                                            ctx)
    }


    public entry fun setTokenBoost<TOKEN>(adminCap: &AdminCap,
                                          powerFactor: u64,
                                          configReg: &mut DaoSnapshotConfig,
                                          version: &mut Version,
                                          ctx: &mut TxContext){
        snapshot::setTokenBoost<TOKEN>(adminCap,
            powerFactor,
                                                configReg,
                                                version,
                                                ctx)
    }

    public entry fun snapshotNft<NFT: key + store>(nfts: vector<NFT>,
                                                   snapshotReg: &mut DaoSnapshotConfig,
                                                   version: &mut Version,
                                                   ctx: &mut TxContext){
        snapshot::snapshotNft<NFT>(nfts,
                                        snapshotReg,
                                        version,
                                        ctx);
    }

    public entry fun unstakeSnapshotNft<NFT: key + store>(snapshotReg: &mut DaoSnapshotConfig,
                                                    version: &mut Version,
                                                    ctx: &mut TxContext){
        snapshot::unsnapshotNft<NFT>(snapshotReg, version, ctx);
    }

    public entry fun stakeSnapshotToken<TOKEN>(tokens: vector<Coin<TOKEN>>,
                                         snapshotReg: &mut DaoSnapshotConfig,
                                         version: &mut Version,
                                         ctx: &mut TxContext){
        snapshot::snapshotToken<TOKEN>(tokens, snapshotReg, version, ctx);
    }

    public entry fun unstakeSnapshotToken<TOKEN>(snapshotReg: &mut DaoSnapshotConfig,
                                           version: &mut Version,
                                           ctx: &mut TxContext){
        snapshot::unsnapshotToken<TOKEN>(snapshotReg, version, ctx);
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
                                            snapshotReg: &DaoSnapshotConfig,
                                            sclock: &Clock,
                                            version: &mut Version,
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
            snapshotReg,
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
        snapshotReg: &DaoSnapshotConfig,
        sclock: &Clock,
        version: &mut Version,
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
            snapshotReg,
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
                                                             snapshotReg: &DaoSnapshotConfig,
                                                             sclock: &Clock,
                                                             version: &mut Version,
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
            snapshotReg,
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
                                           sclock: &Clock,
                                           snapshotReg: &DaoSnapshotConfig,
                                           version: &mut Version,
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
            snapshotReg,
            version,
            ctx)
    }

    /// Delist when proposal in init!
    public entry fun delistProposal(proposalId: address,
                                    dao: &mut Dao,
                                    version: &mut Version,
                                    ctx: &mut TxContext){
        proposal::delistProposal(proposalId, dao, version, ctx);
    }


    ///Owner officially start proposal
    public entry fun listProposal(proposalId: address,
                                  dao: &mut Dao,
                                  sclock: &Clock,
                                  version: &mut Version,
                                  ctx: &mut TxContext){
        proposal::listProposal(proposalId, dao, sclock, version, ctx);
    }


    ///VOTING
    ///
    public fun voteBySnapshotPower(propAddr: address,
                                   dao: &mut Dao,
                                   choices: vector<u8>,
                                   choiceValues: vector<u64>,
                                   powerUsed: u64,
                                   snapshotReg: &DaoSnapshotConfig,
                                   sclock: &Clock,
                                   version: &mut Version,
                                   ctx: &mut TxContext){
        proposal::voteBySnapshotPower(
            propAddr,
            dao,
            choices,
            choiceValues,
            powerUsed,
            snapshotReg,
            sclock,
            version,
            ctx
        );
    }

    ///User vote using token power
    public entry fun voteByCoin<TOKEN: key + store>(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choiceValues: vector<u64>,
        coins: vector<Coin<TOKEN>>,
        powerUsed: u64,
        snapshotReg: &DaoSnapshotConfig,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ){
        proposal::voteByCoin<TOKEN>(proposalId,
            dao,
            choices,
            choiceValues,
            coins,
            powerUsed,
            snapshotReg,
            sclock,
            version,
            ctx);
    }

    ///User vote using NFT power
    public entry fun voteByNft<NFT: key + store>(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choiceValues: vector<u64>,
        nfts: vector<NFT>,
        powerUsed: u64,
        snapshotReg: &DaoSnapshotConfig,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        proposal::voteByNfts<NFT>(proposalId,
            dao,
            choices,
            choiceValues,
            nfts,
            powerUsed,
            snapshotReg,
            sclock,
            version,
            ctx);
    }

    ///Anonymous user vote
    public entry fun voteAnonymous(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choiceValues: vector<u64>,
        powerUsed: u64,
        snapshotReg: &DaoSnapshotConfig,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        proposal::voteByAnonymous(proposalId,
            dao,
            choices,
            choiceValues,
            powerUsed,
            snapshotReg,
            sclock,
            version,
            ctx);
    }

    ///User unvote
    public entry fun unvote(proposalId: address,
                            dao: &mut Dao,
                            sclock: &Clock,
                            version: &mut Version,
                            ctx: &mut TxContext) {
        proposal::unvote(proposalId, dao, sclock, version,ctx);
    }

    ///Admin finalize proposal
    ///@todo who responsible to finalize proposal ?
    public entry fun finalize(adminCap: &AdminCap,
                              proposalId: address,
                              dao: &mut Dao,
                              sclock: &Clock,
                              version: &mut Version,
                              ctx: &mut TxContext) {
        proposal::finalize(adminCap, proposalId, dao, sclock, version, ctx);
    }
}
