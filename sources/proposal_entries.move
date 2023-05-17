module gize::proposal_entries {
    use gize::proposal::{Dao, Proposal, DaoRoleCap};
    use sui::tx_context::TxContext;
    use gize::proposal;
    use sui::coin::Coin;
    use sui::clock::Clock;
    use gize::version::Version;
    use gize::config::AdminCap;

    ///Create DAO by admin
    public entry fun createDao(adminCap: &AdminCap,
                               owner: address,
                               submitPropThres: u64,
                               anonymousPowerFactor: u64,
                               version: &mut Version,
                               ctx: &mut TxContext){
        proposal::createDao(adminCap, owner, anonymousPowerFactor, submitPropThres, version, ctx);
    }

    ///Add new DAO admin by owner
    public entry fun setDaoAdmin(daoRoleCap: &DaoRoleCap,
                                 adminAddr: address,
                                 expireTime: u64,
                                 dao: &mut Dao,
                                 sclock: &Clock,
                                 version: &mut Version,
                                 ctx: &mut TxContext){
        proposal::addDaoAdmin(daoRoleCap, adminAddr, expireTime, dao, version, sclock, ctx);
    }

    ///Add new DAO operator by admin
    public entry fun setDaoOperator(roleCap: &DaoRoleCap,
                                    operatorAddr: address,
                                    expireTime: u64,
                                    dao: &mut Dao,
                                    sclock: &Clock,
                                    version: &mut Version,
                                    ctx: &mut TxContext){
        proposal::addDaoOperator(roleCap, operatorAddr, expireTime, dao, sclock, version, ctx);
    }

    public entry fun setNftBoost<NFT: key + store>(roleCap: &DaoRoleCap,
                                                   powerFactor: u64,
                                                   dao: &mut Dao,
                                                   version: &mut Version,
                                                   sclock: &Clock){
        proposal::setNftBoost<NFT>(roleCap,
                                    powerFactor,
                                    dao,
                                    sclock,
                                    version)
    }


    public entry fun setTokenBoost<TOKEN>(roleCap: &DaoRoleCap,
                                          powerFactor: u64,
                                          dao: &mut Dao,
                                          version: &mut Version,
                                          sclock: &Clock){
        proposal::setTokenBoost<TOKEN>(roleCap,
                                        powerFactor,
                                        dao,
                                        sclock,
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

    public entry fun unnapshotNft<NFT: key + store>(dao: &mut Dao,
                                                    version: &mut Version,
                                                    ctx: &mut TxContext){
        proposal::unsnapshotNft<NFT>(dao, version, ctx);
    }

    public entry fun snapshotToken<TOKEN>(tokens: vector<Coin<TOKEN>>,
                                          dao: &mut Dao,
                                          version: &mut Version,
                                          ctx: &mut TxContext){
        proposal::snapshotToken<TOKEN>(tokens, dao, version, ctx);
    }

    public entry fun unsnapshotToken<TOKEN>(dao: &mut Dao,
                                            version: &mut Version,
                                            ctx: &mut TxContext){
        proposal::unsnapshotToken<TOKEN>(dao, version, ctx);
    }

    ///Operator make new proposal
    public entry fun submitProposalByRole(roleCap: &DaoRoleCap,
                                          name: vector<u8>,
                                          description: vector<u8>,
                                          threadLink: vector<u8>,
                                          type: u8,
                                          votePowerThreshold: u64,
                                          voteType: u8,
                                          expire: u64,
                                          choiceCodes: vector<u8>,
                                          choiceNames: vector<vector<u8>>,
                                          dao: &mut Dao,
                                          version: &mut Version,
                                          sclock: &Clock,
                                          ctx: &mut TxContext)
    {
        proposal::submitProposalByRole(roleCap,
            name,
            description,
            threadLink,
            type,
            votePowerThreshold,
            voteType,
            expire,
            choiceCodes,
            choiceNames,
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
            dao,
            sclock,
            nfts,
            version,
            ctx);
    }

    ///Sumbit proposal using staked power
    public entry fun submitProposalBySnapshotPower(name: vector<u8>,
                                                   description: vector<u8>,
                                                   threadLink: vector<u8>,
                                                   type: u8,
                                                   votePowerThreshold: u64,
                                                   voteType: u8,
                                                   expire: u64,
                                                   choiceCodes: vector<u8>,
                                                   choiceNames: vector<vector<u8>>,
                                                   dao: &mut Dao,
                                                   version: &mut Version,
                                                   sclock: &Clock,
                                                   ctx: &mut TxContext) {
        proposal::submitProposalBySnapshotPower(name,
            description,
            threadLink,
            type,
            votePowerThreshold,
            voteType,
            expire,
            choiceCodes,
            choiceNames,
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
                                   powerUsed: u64,
                                   version: &mut Version,
                                   sclock: &Clock,
                                   ctx: &mut TxContext){
        proposal::voteBySnapshotPower(
            prop,
            dao,
            choices,
            powerUsed,
            sclock,
            version,
            ctx
        );
    }

    ///User vote using token power
    public entry fun voteByToken<TOKEN: key + store>(
        prop: &mut Proposal,
        dao: &mut Dao,
        choices: vector<u8>,
        coins: vector<Coin<TOKEN>>,
        powerUsed: u64,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext
    ){
        proposal::voteByToken<TOKEN>(prop,
            dao,
            choices,
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
        nfts: vector<NFT>,
        powerUsed: u64,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        proposal::voteByNfts<NFT>(prop,
            dao,
            choices,
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
