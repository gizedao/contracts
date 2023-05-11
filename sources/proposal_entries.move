module gize::proposal_entries {
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
    public entry fun createDao(admin: &AdminCap,
                               version: &mut Version,
                               ctx: &mut TxContext){
        proposal::createDao(admin, version, ctx);
    }

    public entry fun setThreshold(_admin: &AdminCap,
                            operatorThreshold: u64,
                            snapshotThreshold: u64,
                            daoConfig: &mut DaoSnapshotConfig,
                            version: &mut Version,
                            _ctx: &mut TxContext){
        snapshot::setThreshold(_admin, operatorThreshold, snapshotThreshold, daoConfig, version, _ctx);
    }

    ///Add new DAO operator by admin
    public entry fun setDaoOperator(admin: &AdminCap,
                              operatorAddr: address,
                              expireTime: u64,
                              boostFactor: u64,
                              daoConfig: &mut DaoSnapshotConfig,
                              sclock: &Clock,
                              version: &mut Version,
                              ctx: &mut TxContext){
        snapshot::setDaoOperator(admin, operatorAddr, expireTime, boostFactor, daoConfig, sclock, version, ctx);
    }


    public entry fun setAnonymousBoost(_adminCap: &AdminCap,
                                 power_factor: u64,
                                 configReg: &mut DaoSnapshotConfig,
                                 version: &mut Version,
                                 ctx: &mut TxContext){
        snapshot::setAnonymousBoost(_adminCap,
                                    power_factor,
                                    configReg,
                                    version,
                                    ctx);
    }

    public entry fun addPowerConfigNft<NFT: key + store>(adminCap: &AdminCap,
                                                   power_factor: u64,
                                                   configReg: &mut DaoSnapshotConfig,
                                                   version: &mut Version,
                                                   ctx: &mut TxContext){
        snapshot::addPowerConfigNft<NFT>(adminCap,
                                            power_factor,
                                            configReg,
                                            version,
                                            ctx)
    }


    public entry fun addPowerConfigToken<TOKEN>(adminCap: &AdminCap,
                                          power_factor: u64,
                                          configReg: &mut DaoSnapshotConfig,
                                          version: &mut Version,
                                          ctx: &mut TxContext){
        snapshot::addPowerConfigToken<TOKEN>(adminCap,
                                                power_factor,
                                                configReg,
                                                version,
                                                ctx)
    }

    public entry fun stakeSnapshotNft<NFT: key + store>(nfts: vector<NFT>,
                                                  snapshotReg: &mut DaoSnapshotConfig,
                                                  version: &mut Version,
                                                  ctx: &mut TxContext){
        snapshot::stakeSnapshotNft<NFT>(nfts,
                                        snapshotReg,
                                        version,
                                        ctx);
    }

    ///Admin make new proposal
    public entry fun submitProposalByAdmin(adminCap: &AdminCap,
                                           name: vector<u8>,
                                           description: vector<u8>,
                                           thread_link: vector<u8>,
                                           type: u8,
                                           vote_type: u8,
                                           token_condition_threshold: u64,
                                           expire: u64,
                                           dao: &mut Dao,
                                           sclock: &Clock,
                                           version: &mut Version,
                                           ctx: &mut TxContext) {
        proposal::submitProposalByAdmin(
            adminCap,
            name,
            description,
            thread_link,
            type,
            vote_type,
            token_condition_threshold,
            expire,
            dao,
            sclock,
            version,
            ctx
        );
    }

    public entry fun unstakeSnapshotNft<NFT: key + store>(snapshotReg: &mut DaoSnapshotConfig,
                                                    version: &mut Version,
                                                    ctx: &mut TxContext){
        snapshot::unstakeSnapshotNft<NFT>(snapshotReg, version, ctx);
    }

    public entry fun stakeSnapshotToken<TOKEN>(tokens: vector<Coin<TOKEN>>,
                                         snapshotReg: &mut DaoSnapshotConfig,
                                         version: &mut Version,
                                         ctx: &mut TxContext){
        snapshot::stakeSnapshotToken<TOKEN>(tokens, snapshotReg, version, ctx);
    }

    public entry fun unstakeSnapshotToken<TOKEN>(snapshotReg: &mut DaoSnapshotConfig,
                                           version: &mut Version,
                                           ctx: &mut TxContext){
        snapshot::unstakeSnapshotToken<TOKEN>(snapshotReg, version, ctx);
    }

    ///Operator make new proposal
    public entry fun submitProposalOperator(name: vector<u8>,
                                              description: vector<u8>,
                                              thread_link: vector<u8>,
                                              type: u8,
                                              vote_power_threshold: u64,
                                              vote_type: u8,
                                              expire: u64,
                                              dao: &mut Dao,
                                                snapshotReg: &DaoSnapshotConfig,
                                              sclock: &Clock,
                                            version: &mut Version,
                                            ctx: &mut TxContext)
    {
        proposal::submitProposalByOperator(name,
            description,
            thread_link,
            type,
            vote_power_threshold,
            vote_type,
            expire,
            dao,
            snapshotReg,
            sclock,
            version,
            ctx);
    }

    ///Boosted user using Token to make new proposal
    public entry fun submitProposalByToken<TOKEN>(
                                     name: vector<u8>,
                                     description: vector<u8>,
                                     thread_link: vector<u8>,
                                     type: u8,
                                     vote_power_threshold: u64,
                                     vote_type: u8,
                                     expire: u64,
                                     dao: &mut Dao,
                                     token: &Coin<TOKEN>,
                                     snapshotReg: &DaoSnapshotConfig,
                                     sclock: &Clock,
                                     version: &mut Version,
                                     ctx: &mut TxContext) {
        proposal::submitProposalByToken<TOKEN>(
            name,
            description,
            thread_link,
            type,
            vote_power_threshold,
            vote_type,
            expire,
            dao,
            token,
            snapshotReg,
            sclock,
            version,
            ctx);
    }

    ///Boosted user using NFT collection to make new proposal
    public entry  fun submitProposalByNfts<NFT: key + store>(name: vector<u8>,
                                                                description: vector<u8>,
                                                                thread_link: vector<u8>,
                                                                type: u8,
                                                                vote_power_threshold: u64,
                                                                vote_type: u8,
                                                                expire: u64,
                                                                dao: &mut Dao,
                                                                nfts: vector<NFT>,
                                                                 snapshotReg: &DaoSnapshotConfig,
                                                                 sclock: &Clock,
                                                                version: &mut Version,
                                                                ctx: &mut TxContext) {
        proposal::submitProposalByNfts<NFT>(
            name,
            description,
            thread_link,
            type,
            vote_power_threshold,
            vote_type,
            expire,
            dao,
            sclock,
            nfts,
            snapshotReg,
            version,
            ctx);
    }

    public fun submitProposalByPower<NFT: key + store>(name: vector<u8>,
                                                       description: vector<u8>,
                                                       thread_link: vector<u8>,
                                                       type: u8,
                                                       vote_power_threshold: u64,
                                                       vote_type: u8,
                                                       expire: u64,
                                                       dao: &mut Dao,
                                                       sclock: &Clock,
                                                       snapshotReg: &DaoSnapshotConfig,
                                                       version: &mut Version,
                                                       ctx: &mut TxContext) {
        proposal::submitProposalByPower(name,
            description,
            thread_link,
            type,
            vote_power_threshold,
            vote_type,
            expire,
            dao,
            sclock,
            snapshotReg,
            version,
            ctx)
    }
    ///Owner officially start proposal
    public entry fun listProposal(proposalId: address,
                                  dao: &mut Dao,
                                  sclock: &Clock,
                                  version: &mut Version,
                                  ctx: &mut TxContext){
        proposal::listProposal(proposalId, dao, sclock, version, ctx);

    }

    public entry fun delistProposal(proposalId: address,
                                    dao: &mut Dao,
                                    version: &mut Version,
                                    ctx: &mut TxContext){
        proposal::delistProposal(proposalId, dao, version, ctx);

    }

    ///User vote using token power
    public entry fun voteByToken<TOKEN: key + store>(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        power: &Coin<TOKEN>,
        snapshotReg: &DaoSnapshotConfig,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ){
        proposal::voteByToken<TOKEN>(proposalId, dao, choices, choice_values, power, snapshotReg, sclock, version, ctx);
    }

    ///User vote using NFT power
    public entry fun voteByNft<NFT: key + store>(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        nfts: vector<NFT>,
        snapshotReg: &DaoSnapshotConfig,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        proposal::voteByNfts<NFT>(proposalId, dao, choices, choice_values, nfts, snapshotReg, sclock, version, ctx);
    }

    ///Anonymous user vote
    public entry fun voteAnonymous(
        proposalId: address,
        dao: &mut Dao,
        choices: vector<u8>,
        choice_values: vector<u64>,
        snapshotReg: &DaoSnapshotConfig,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        proposal::voteByAnonymous(proposalId, dao, choices, choice_values, snapshotReg, sclock, version, ctx);
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
    public entry fun finalize(_admin: &AdminCap,
                              proposalId: address,
                              dao: &mut Dao,
                              sclock: &Clock,
                              version: &mut Version,
                              ctx: &mut TxContext) {
        proposal::finalize(_admin, proposalId, dao, sclock, version, ctx);
    }
}
