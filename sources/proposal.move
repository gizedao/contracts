///
/// @Note
/// - @todo make sure when any proposal running: dont change dao config
/// - exchange power to vote: currently 1 power = 1 vote
/// - allocate power on choices:
///     + single choice: just count up
///     + multi choices: divide equally
///     + yes/no/abstand: one special case of multichoice, currently divide equally.
///     In the future, will allocate according to quardratic distribution
/// - proposal have not state of PASS or FAILED, just DONE. Summary of vote will be used offchain!
module gize::proposal {
    use std::vector;
    use std::type_name::TypeName;
    use std::type_name;
    use sui::object::{UID, id_address};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::{public_share_object, share_object, transfer};
    use sui::object;
    use sui::table::Table;
    use sui::table;
    use sui::coin::Coin;
    use sui::coin;
    use sui::clock::{Clock, timestamp_ms};
    use sui::clock;
    use sui::event::emit;
    use sui::math;
    use sui::vec_map::VecMap;
    use sui::vec_map;
    use sui::math::min;
    use sui::dynamic_field;
    use sui::pay;

    use gize::version::{Version, checkVersion};
    use gize::common::transferAssetVector;
    use gize::config::AdminCap;
    use gize::common;

    struct PROPOSAL has drop {}

    const VERSION: u64 = 1;

    const ONE_UNDRED_SCALED_10000: u64 = 10000;
    const MAX_CHOICES: u8 = 100;

    const ERR_NOT_SUPPORTED: u64 = 1001;
    const ERR_INVALID_STATE: u64 = 1002;
    const ERR_INVALID_CHOICE: u64 = 1003;
    const ERR_PROPOSAL_NOT_FOUND: u64 = 1004;
    const ERR_INVALID_PARAMS: u64 = 1005;
    const ERR_NOT_ENOUGHT_POWER: u64 = 1006;
    const ERR_NOT_WHITELISTED: u64 = 1007;
    const ERR_ALREADY_VOTED: u64 = 1008;
    const ERR_NOT_VOTED: u64 = 1009;
    const ERR_INVALID_EXPIRE_TIME: u64 = 1010;
    const ERR_OPERATOR_EXPIRED: u64 = 1011;
    const ERR_PERMISSION: u64 = 1012;
    const ERR_SNAPSHOT_NOT_EMPTY: u64 = 1013;

    const ERR_DAO_RUNNING: u64 = 2002;

    const PROPOSAL_TYPE_ONCHAIN: u8 = 1;  //on chain, ready for voting
    const PROPOSAL_TYPE_OFFCHAIN: u8 = 2; //off chain, no need to vote

    const PROPOSAL_VOTE_TYPE_SINGLE: u8 = 1;  //single choice only
    const PROPOSAL_VOTE_TYPE_MULTI: u8 = 2; //multi choice with the same weight
    const PROPOSAL_VOTE_TYPE_MULTI_QUADRATIC: u8 = 3; //multi choice with the weight allocated by quadratic

    const ROLE_OWNER: u8 = 4; //0000 0100
    const ROLE_ADMIN: u8 = 2; //0000 0010
    const ROLE_OPERATOR: u8 = 1; //0000 0001

    const ONE_HOURS_IN_MS: u64 = 3600000;

    struct DaoRoleCap has key, store {
        id: UID,
        role: u8,
        expire_time: u64, //0: mean never expired!
        dao: address
    }

    struct AssetSnapshot has key, store {
        id: UID,
        total_object: u64
        //dynamic filed of TypeName > vector<AssetType>
    }

    struct BoostConfig has drop, store, copy {
        factor: u64   //power factor, for example: NFT size * power_factor
    }

    struct Choice has drop, copy, store {
        code: u8,   //code
        name: vector<u8>, //name
        voted: u64, //total votes allocated
        passed: bool
    }

    struct VoteAllocation has drop, copy, store{
        choice: u8,
        allocation: u64
    }
    struct UserVote has drop, copy, store {
        power: u64,
        allocations: vector<VoteAllocation>
    }

    const PROP_STATE_INIT:u8 = 1;
    const PROP_STATE_DELISTED:u8 = 2;
    const PROP_STATE_PENDING:u8 = 3;
    const PROP_STATE_PASSED:u8 = 4;
    const PROP_STATE_FAILED:u8 = 5;

    struct Proposal has key, store {
        id: UID,
        owner: address, //owner of prop
        dao: address,   //DAO belongs to
        state: u8,
        name: vector<u8>,
        description: vector<u8>,
        thread_link: vector<u8>, //offchain discussion
        type: u8, //on chain|off chain
        vote_power_threshold: u64, //minimum power allowed to vote
        vote_type: u8, //single | multiple weighted. multiple equally is one special case of multiple weighted
        choices: VecMap<u8, Choice>, //fore example: code -> Choice!
        user_votes: Table<address, UserVote>, //cache user votes, to prevent double votes, support revoking votes
        expire: u64, //expired timestamp
        pass_threshold: u64
    }

    struct Dao has key, store {
        id: UID,
        owner: address,
        submit_prop_threshold: u64,   //submit proposal threshold
        anonymous_boost: BoostConfig,   //anonymous boost factor
        nft_boost: Table<TypeName, BoostConfig>,   //nft whitelist & factor
        token_boost: Table<TypeName, BoostConfig>,  //token whitelist & factor
        powers: Table<address, u64>, //vote power by snapshoting asset
        asset_snapshot: Table<address, AssetSnapshot>, //asset snapshot bag
        proposals: Table<address, u8>
    }

    struct DaoCreatedEvent has copy, drop {
        id: address,
        owner: address,
    }

    struct ProposalSubmittedEvent has copy, drop {
        id: address,
        state: u8,
        name: vector<u8>,
        description: vector<u8>,
        thread_link: vector<u8>,
        type: u8,
        vote_power_threshold: u64,
        vote_type: u8,
        expire: u64,
        pass_threshold: u64
    }

    struct ProposalListedEvent has copy, drop {
        id: address,
        state: u8,
        name: vector<u8>,
        description: vector<u8>,
        thread_link: vector<u8>,
        type: u8,
        vote_power_threshold: u64,
        vote_type: u8,
        choices: VecMap<u8, Choice>,
        expire: u64,
    }

    struct ProposalDelistedEvent has copy, drop {
        id: address,
        state: u8,
        name: vector<u8>,
        description: vector<u8>,
        thread_link: vector<u8>,
        type: u8,
        vote_power_threshold: u64,
        vote_type: u8,
        choices: VecMap<u8, Choice>,
        expire: u64,
    }

    struct ProposalFinalizedEvent has copy, drop {
        id: address,
        state: u8,
        name: vector<u8>,
        description: vector<u8>,
        thread_link: vector<u8>,
        type: u8,
        vote_power_threshold: u64,
        vote_type: u8,
        choices: VecMap<u8, Choice>,
        expire: u64,
        total_users: u64,
    }

    struct VotedEvent has copy, drop {
        id: address,
        user_vote: UserVote
    }

    struct UnvotedEvent has copy, drop {
        id: address,
        user_vote: UserVote
    }

    struct ProposalChoiceAddedEvent has copy, drop {
        id: address,
        choice: Choice
    }

    public fun createDao(_admin: &AdminCap,
                         owner: address,
                         submitPropThres: u64,
                         anonymousPowerFactor: u64,
                         version: &mut Version,
                         ctx: &mut TxContext){
        checkVersion(version, VERSION);
        let dao = Dao {
            id: object::new(ctx),
            owner,
            submit_prop_threshold: submitPropThres,
            anonymous_boost: BoostConfig {
                factor: anonymousPowerFactor,
            },
            nft_boost: table::new(ctx),
            token_boost: table::new(ctx),
            powers: table::new(ctx),
            asset_snapshot: table::new(ctx),
            proposals: table::new(ctx)
        };

        let daoId = id_address(&dao);
        transfer(DaoRoleCap {id: object::new(ctx), role: ROLE_OWNER, expire_time: 0, dao: daoId,}, owner);
        public_share_object(dao);

        emit(DaoCreatedEvent {
            id: daoId,
            owner
        });
    }

    public fun submitProposalByRole(roleCap: &DaoRoleCap,
                                    name: vector<u8>,
                                    description: vector<u8>,
                                    threadLink: vector<u8>,
                                    type: u8,
                                    votePowerThreshold: u64,
                                    voteType: u8,
                                    expire: u64,
                                    choiceCodes: vector<u8>,
                                    choiceNames: vector<vector<u8>>,
                                    pass_threshold: u64,
                                    dao: &mut Dao,
                                    sclock: &Clock,
                                    version: &mut Version,
                                    ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        validateRole(roleCap, ROLE_OPERATOR, dao, sclock);
        submitProposal(name, description, threadLink, type,
            votePowerThreshold, voteType, expire, choiceCodes,
            choiceNames, pass_threshold, dao, sclock, ctx);
    }

    public fun submitProposalByToken<TOKEN>(name: vector<u8>,
                                            description: vector<u8>,
                                            threadLink: vector<u8>,
                                            type: u8,
                                            votePowerThreshold: u64,
                                            voteType: u8,
                                            expire: u64,
                                            choiceCodes: vector<u8>,
                                            choiceNames: vector<vector<u8>>,
                                            pass_threshold: u64,
                                            dao: &mut Dao,
                                            token: &Coin<TOKEN>,
                                            sclock: &Clock,
                                            version: &mut Version,
                                            ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        validateTokenVoteWhitelisted<TOKEN>(dao);
        let power = getTokenBoostFactor<TOKEN>(dao) * coin::value(token);
        assert!(power >= dao.submit_prop_threshold , ERR_PERMISSION);

        submitProposal(name, description, threadLink, type, votePowerThreshold,
            voteType, expire, choiceCodes, choiceNames, pass_threshold, dao, sclock, ctx);
    }

    public fun submitProposalByNfts<NFT: key + store>(name: vector<u8>,
                                                      description: vector<u8>,
                                                      threadLink: vector<u8>,
                                                      type: u8,
                                                      votePowerThreshold: u64,
                                                      voteType: u8,
                                                      expire: u64,
                                                      choiceCodes: vector<u8>,
                                                      choiceNames: vector<vector<u8>>,
                                                      pass_threshold: u64,
                                                      dao: &mut Dao,
                                                      sclock: &Clock,
                                                      nfts: vector<NFT>,
                                                      version: &mut Version,
                                                      ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        validateNftVoteWhitelisted<NFT>(dao);

        let power = getTokenBoostFactor<NFT>(dao) * vector::length(&nfts);
        assert!( power >= dao.submit_prop_threshold , ERR_PERMISSION);
        submitProposal(name, description, threadLink, type, votePowerThreshold,
            voteType, expire, choiceCodes, choiceNames, pass_threshold, dao, sclock, ctx);

        transferAssetVector(nfts, sender(ctx));
    }

    public fun submitProposalBySnapshotPower(name: vector<u8>,
                                             description: vector<u8>,
                                             threadLink: vector<u8>,
                                             type: u8,
                                             votePowerThreshold: u64,
                                             voteType: u8,
                                             expire: u64,
                                             choiceCodes: vector<u8>,
                                             choiceNames: vector<vector<u8>>,
                                             pass_threshold: u64,
                                             dao: &mut Dao,
                                             sclock: &Clock,
                                             version: &mut Version,
                                             ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let power = getVotingPower(sender(ctx), dao);
        assert!( power >= dao.submit_prop_threshold , ERR_PERMISSION);

        submitProposal(name, description, threadLink, type, votePowerThreshold,
            voteType, expire, choiceCodes, choiceNames, pass_threshold, dao, sclock, ctx);
    }

    fun submitProposal(name: vector<u8>,
                       description: vector<u8>,
                       threadLink: vector<u8>,
                       type: u8,
                       votePowerThreshold: u64,
                       voteType: u8,
                       expire: u64,
                       choiceCodes: vector<u8>,
                       choice_names: vector<vector<u8>>,
                       pass_threshold: u64,
                       dao: &mut Dao,
                       sclock: &Clock,
                       ctx: &mut TxContext){

        assert!(vector::length(&description) > 0
                && vector::length(&threadLink) > 0
                && (type == PROPOSAL_TYPE_ONCHAIN || type == PROPOSAL_TYPE_OFFCHAIN)
                && (voteType == PROPOSAL_VOTE_TYPE_SINGLE || voteType == PROPOSAL_VOTE_TYPE_MULTI)
                && expire > clock::timestamp_ms(sclock)
                && vector::length(&choiceCodes) > 0
                &&(vector::length(&choiceCodes) == vector::length(&choice_names)
                && pass_threshold > 0),
            ERR_INVALID_PARAMS);

        let prop = Proposal{
            id: object::new(ctx),
            owner: sender(ctx),
            dao: id_address(dao),
            state: PROP_STATE_INIT,
            name,
            description,
            thread_link: threadLink,
            type,
            vote_power_threshold: votePowerThreshold,
            vote_type: voteType,
            choices: vec_map::empty(),
            user_votes: table::new(ctx),
            expire,
            pass_threshold
        };

        while (!vector::is_empty(&choiceCodes)){
            addProposalChoice(vector::pop_back(&mut choiceCodes),
                        vector::pop_back(&mut choice_names),
            &mut prop);
        };

        let event = ProposalSubmittedEvent {
            id: id_address(&prop),
            state: prop.state,
            name,
            description,
            thread_link: threadLink,
            type,
            vote_power_threshold: votePowerThreshold,
            vote_type: voteType,
            expire,
            pass_threshold
        };

        table::add(&mut dao.proposals, id_address(&prop), prop.state);
        share_object(prop);
        emit(event)
    }

    fun addProposalChoice(code: u8,
                           name: vector<u8>,
                           prop: &mut Proposal){
        assert!((code < MAX_CHOICES)
                && vector::length(&name) > 0
                && vec_map::contains(&mut prop.choices, &code)
                , ERR_INVALID_CHOICE);

        if(vec_map::contains(&mut prop.choices, &code)){
            let choice = vec_map::get_mut(&mut prop.choices, &code);
            choice.name = name;
            choice.voted = 0;
        } else{
            let choice =  Choice {
                code,
                name,
                voted: 0u64,
                passed: false
            };

            vec_map::insert(&mut prop.choices, code, choice);
        };
    }

    public fun listProposal(prop: &mut Proposal,
                            sclock: &Clock,
                            version: &mut Version,
                            ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validatePropOwner(prop, ctx);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        assert!(vec_map::size(&prop.choices) > 0 && clock::timestamp_ms(sclock) < prop.expire, ERR_INVALID_PARAMS);
        prop.state  = PROP_STATE_PENDING;

        emit(ProposalListedEvent {
            id: id_address(prop),
            state: prop.state,
            name: prop.name,
            description: prop.description,
            thread_link: prop.thread_link,
            type: prop.type,
            vote_power_threshold: prop.vote_power_threshold,
            vote_type: prop.vote_type,
            choices: prop.choices,
            expire: prop.expire,
        })
    }

    public fun delistProposal(prop: Proposal,
                                dao: &mut Dao,
                                version: &mut Version,
                                ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validatePropVsDao(dao, &prop);
        validatePropOwner(&prop, ctx);

        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        prop.state  = PROP_STATE_DELISTED;

        let propId = id_address(&prop);
        emit(ProposalDelistedEvent {
            id: propId,
            state: prop.state,
            name: prop.name,
            description: prop.description,
            thread_link: prop.thread_link,
            type: prop.type,
            vote_power_threshold: prop.vote_power_threshold,
            vote_type: prop.vote_type,
            choices: prop.choices,
            expire: prop.expire,
        });
        table::remove(&mut dao.proposals, propId);
        destroyProposal(prop);
    }

    ///
    /// Vote using power staked by snapshot
    ///
    public fun voteBySnapshotPower(prop: &mut Proposal,
                                   dao: &mut Dao,
                                   choices: vector<u8>,
                                   powerUsed: u64,
                                   sclock: &Clock,
                                   version: &mut Version,
                                   ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validatePropVsDao(dao, prop);
        validatePropState2Vote(sclock, prop);

        //in-the case have no power, act as anonymous
        let power = math::max(getVotingPower(sender(ctx), dao), dao.anonymous_boost.factor);
        power = math::min(power, powerUsed);

        //event
        emit(VotedEvent {
            id: id_address(prop),
            user_vote: distributeVote(prop, choices, power, ctx)
        })
    }

    ///
    /// Directly vote by coin list
    ///
    public fun voteByToken<TOKEN: key + store>(prop: &mut Proposal,
                                               dao: &mut Dao,
                                               choices: vector<u8>,
                                               coins: vector<Coin<TOKEN>>,
                                               powerUsed: u64,
                                               sclock: &Clock,
                                               version: &mut Version,
                                               ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validatePropVsDao(dao, prop);
        validatePropState2Vote(sclock, prop);
        validateTokenVoteWhitelisted<TOKEN>(dao);

        let totalVal = common::totalValue(&coins);
        assert!(totalVal > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let factor = getTokenBoostFactor<TOKEN>(dao);
        let power = factor * totalVal;
        power = min(power, powerUsed);

        //transfer back
        common::transferAssetVector(coins, sender(ctx));

        let userVote = distributeVote(prop, choices, power, ctx);

        //event
        emit(VotedEvent {
            id: id_address(prop),
            user_vote: userVote
        })
    }

    ///
    /// Directly vote by NFT collection
    ///
    public fun voteByNfts<NFT: key + store>(prop: &mut Proposal,
                                            dao: &mut Dao,
                                            choices: vector<u8>,
                                            nfts: vector<NFT>,
                                            powerUsed: u64,
                                            sclock: &Clock,
                                            version: &mut Version,
                                            ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validatePropVsDao(dao, prop);
        validatePropState2Vote(sclock, prop);
        validateNftVoteWhitelisted<NFT>(dao);

        //distribute vote
        let factor = getNftBoostFactor<NFT>(dao);
        let power = math::min(powerUsed, factor * vector::length(&nfts));
        let userVote = distributeVote(prop, choices, power, ctx);

        //return nfts
        transferAssetVector(nfts, sender(ctx));

        //event
        emit(VotedEvent {
            id: id_address(prop),
            user_vote: userVote
        })
    }

    public fun unvote(prop: &mut Proposal,
                      dao: &mut Dao,
                      sclock: &Clock,
                      version: &mut Version,
                      ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validatePropVsDao(dao, prop);
        validatePropState2Vote(sclock, prop);

        let senderAddr = sender(ctx);
        assert!(table::contains(&prop.user_votes, senderAddr), ERR_NOT_VOTED);

        let userVote = table::remove(&mut prop.user_votes, senderAddr);
        let allocs  = &mut userVote.allocations;

        while (!vector::is_empty(allocs)){
            let alloc = vector::pop_back(allocs);
            let choice = vec_map::get_mut(&mut prop.choices, &alloc.choice);
            choice.voted = choice.voted - alloc.allocation;
        };

        emit(UnvotedEvent {
            id: id_address(prop),
            user_vote: userVote
        })
    }

    ///
    /// Finalize proposal
    ///
    public fun finalize(prop: &mut Proposal,
                        dao: &mut Dao,
                        sclock: &Clock,
                        version: &mut Version,
                        ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validatePropOwner(prop, ctx);
        validatePropVsDao(dao, prop);
        validatePropState2Vote(sclock, prop);

        let choices = prop.choices;
        let threshold = prop.pass_threshold;
        let passed = false;
        let keys = vec_map::keys(&choices);
        while (!vector::is_empty(&keys)){
            let choice = vec_map::get_mut(&mut choices, &vector::pop_back(&mut keys));
            choice.passed = choice.voted >= threshold;
            passed = passed || choice.passed;
        };

        prop.state = if(passed) {PROP_STATE_PASSED} else {PROP_STATE_FAILED};

        emit(ProposalFinalizedEvent {
            id: id_address(prop),
            state: prop.state,
            name: prop.name,
            description: prop.description,
            thread_link: prop.thread_link,
            type: prop.type,
            vote_power_threshold: prop.vote_power_threshold,
            vote_type: prop.vote_type,
            choices: prop.choices,
            expire: prop.expire,
            total_users: table::length(&prop.user_votes),
        })
    }

    fun distributeVote(prop: &mut Proposal,
                       choices: vector<u8>,
                       power: u64,
                       ctx: &mut TxContext): UserVote {
        //make sure not voted
        let senderAddr = sender(ctx);
        assert!(!table::contains(&prop.user_votes, senderAddr)
            && power >= prop.vote_power_threshold, ERR_INVALID_PARAMS);

        //now distribute vote
        let allocations = vector::empty<VoteAllocation>();

        if(prop.vote_type == PROPOSAL_VOTE_TYPE_SINGLE){
            //allocate all power to single choice
            assert!(vector::length(&choices) == 1, ERR_INVALID_PARAMS);
            let choiceType = *vector::borrow(&choices, 0);
            let choice = vec_map::get_mut(&mut prop.choices, &choiceType);
            choice.voted = choice.voted + power;
            vector::push_back(&mut allocations, VoteAllocation {
                choice: choiceType,
                allocation: power
            });
        }
        else if(prop.vote_type == PROPOSAL_VOTE_TYPE_MULTI){
            //allocate to multi choices: how many percent scaled of power amount allocated for each type ?
            let index = 0;
            let subPower = power/vector::length(&choices);
            while (index < vector::length(&choices)){
                let choiceType = *vector::borrow(&choices, index);
                let choice = vec_map::get_mut(&mut prop.choices, &choiceType);
                choice.voted = choice.voted + subPower;
                index = index + 1;
                vector::push_back(&mut allocations, VoteAllocation {
                    choice: choiceType,
                    allocation: subPower
                });
            };
        }
        else if(prop.vote_type == PROPOSAL_VOTE_TYPE_MULTI_QUADRATIC){
            abort ERR_NOT_SUPPORTED
        };

        let userVote = UserVote {
            power,
            allocations
        };

        table::add(&mut prop.user_votes, sender(ctx), userVote);

        userVote
    }

    fun destroyProposal(prop: Proposal){
        let Proposal {
            id,
            owner: _owner,
            dao: _dao,
            state: _state,
            name: _name,
            description: _description,
            thread_link: _thread_link,
            type:_type,
            vote_power_threshold:_vote_power_threshold,
            vote_type:_vote_type,
            choices:_choices,
            user_votes,
            expire:_expire,
            pass_threshold: _pass_threshold
        } = prop;

        object::delete(id);
        table::drop(user_votes);
    }

    public fun addDaoAdmin(roleCap: &DaoRoleCap,
                           adminAddr: address,
                           expireTime: u64,
                           dao: &mut Dao,
                           version: &mut Version,
                           sclock: &Clock,
                           ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validateRole(roleCap, ROLE_OWNER, dao, sclock);
        assert!(timestamp_ms(sclock) + ONE_HOURS_IN_MS < expireTime , ERR_INVALID_PARAMS);
        transfer(DaoRoleCap {
            id: object::new(ctx),
            role: ROLE_ADMIN,
            expire_time: expireTime,
            dao: id_address(dao)
        }, adminAddr);
    }

    public fun addDaoOperator(roleCap: &DaoRoleCap,
                              opAddr: address,
                              expireTime: u64,
                              dao: &mut Dao,
                              sclock: &Clock,
                              version: &mut Version,
                              ctx: &mut TxContext){
        checkVersion(version, VERSION);
        validateRole(roleCap, ROLE_ADMIN, dao, sclock);
        assert!(expireTime > clock::timestamp_ms(sclock), ERR_INVALID_PARAMS);
        assert!(table::length(&dao.asset_snapshot) == 0, ERR_DAO_RUNNING);
        transfer(DaoRoleCap { id: object::new(ctx), expire_time: expireTime, role: ROLE_OPERATOR, dao: id_address(dao)}, opAddr);
    }

    public fun setNftBoost<NFT: key + store>(roleCap: &DaoRoleCap,
                                             power_factor: u64,
                                             dao: &mut Dao,
                                             sclock: &Clock,
                                             version: &mut Version){
        checkVersion(version, VERSION);
        validateRole(roleCap, ROLE_ADMIN, dao, sclock);
        assert!(table::length(&dao.asset_snapshot) == 0, ERR_DAO_RUNNING);

        let typeName = type_name::get<NFT>();
        if(table::contains(&dao.nft_boost, typeName)){
            table::remove(&mut dao.nft_boost, typeName);
        };

        table::add(&mut dao.nft_boost, typeName, BoostConfig {
            factor: power_factor,
        });
    }

    public fun setTokenBoost<TOKEN>(roleCap: &DaoRoleCap,
                                    boostFactor: u64,
                                    dao: &mut Dao,
                                    sclock: &Clock,
                                    version: &mut Version){
        checkVersion(version, VERSION);
        validateRole(roleCap, ROLE_ADMIN, dao, sclock);
        assert!(table::length(&dao.asset_snapshot) == 0, ERR_DAO_RUNNING);

        let typeName = type_name::get<TOKEN>();
        let tokenBoost = &mut dao.token_boost;
        if(table::contains(tokenBoost, typeName)){
            table::remove(tokenBoost, typeName);
        };

        table::add(&mut dao.token_boost, typeName, BoostConfig {
            factor: boostFactor,
        });
    }

    ///stake asset to get more power
    public fun snapshotNft<NFT: key + store>(nfts: vector<NFT>,
                                             dao: &mut Dao,
                                             version: &mut Version,
                                             ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let nftSize =  vector::length(&nfts);
        let typeName = type_name::get<NFT>();

        //validate
        assert!(nftSize > 0
            && table::contains(&dao.nft_boost, typeName)
            && table::borrow(&dao.nft_boost, typeName).factor > 0,
            ERR_INVALID_PARAMS);
        let senderAddr = sender(ctx);

        //init snapshot bag
        if(!table::contains(&mut dao.asset_snapshot, senderAddr)){
            table::add(&mut dao.asset_snapshot, senderAddr, AssetSnapshot {
                id: object::new(ctx),
                total_object: 0
            })
        };

        let snapshot = table::borrow_mut(&mut dao.asset_snapshot, senderAddr);
        if(!dynamic_field::exists_(&snapshot.id, typeName)){
            dynamic_field::add(&mut snapshot.id, typeName, vector::empty<NFT>())
        };

        //stake asset
        let assetBranch = dynamic_field::borrow_mut(&mut snapshot.id, typeName);
        vector::append(assetBranch, nfts);
        snapshot.total_object = snapshot.total_object + nftSize;

        //update power
        let powerConfig = table::borrow(&dao.nft_boost, typeName);
        common::increaseTable(&mut dao.powers, senderAddr, nftSize * powerConfig.factor);
    }

    /// Unstake asset, power reduced
    public fun unsnapshotNft<NFT: key + store>(dao: &mut Dao,
                                               version: &mut Version,
                                               ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate
        let senderAddr = sender(ctx);
        let snapshots = &mut dao.asset_snapshot;
        let nftBoost = &mut dao.nft_boost;
        let powers = &mut dao.powers;

        assert!(table::contains(snapshots, senderAddr), ERR_INVALID_PARAMS);
        let snapshot = table::borrow_mut(snapshots, senderAddr);
        let typeName = type_name::get<NFT>();
        assert!(dynamic_field::exists_(&snapshot.id, typeName), ERR_INVALID_PARAMS);

        //withdraw all asset branch
        let assetBranch = dynamic_field::remove<TypeName, vector<NFT>>(&mut snapshot.id, typeName);
        let nftSize = vector::length(&assetBranch);
        transferAssetVector(assetBranch, senderAddr);

        //reduce power
        snapshot.total_object = snapshot.total_object - nftSize;
        let powerConfig = table::borrow(nftBoost, typeName);
        common::decreaseTable(powers, senderAddr, nftSize* powerConfig.factor);

        if(snapshot.total_object == 0){
            destroyAssetSnapshot(table::remove(snapshots, senderAddr));
            table::remove(&mut dao.powers, senderAddr);
        };
    }

    ///stake asset to get more power
    public fun snapshotToken<TOKEN>(tokens: vector<Coin<TOKEN>>,
                                    dao: &mut Dao,
                                    version: &mut Version,
                                    ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let typeName = type_name::get<TOKEN>();
        let snapshots = &mut dao.asset_snapshot;
        let tokenBoost = &mut dao.token_boost;
        let powers = &mut dao.powers;

        //validate
        assert!(vector::length(&tokens) > 0
            && table::contains(tokenBoost, typeName)
            && table::borrow(tokenBoost, typeName).factor > 0,
            ERR_INVALID_PARAMS);

        let joinedToken = coin::zero<TOKEN>(ctx);
        pay::join_vec(&mut joinedToken, tokens);
        let tokenVal = coin::value(&joinedToken);
        assert!( tokenVal > 0, ERR_INVALID_PARAMS);

        let senderAddr = sender(ctx);

        //init snapshot bag
        if(!table::contains(snapshots, senderAddr)){
            table::add(snapshots, senderAddr, AssetSnapshot {
                id: object::new(ctx),
                total_object: 0
            })
        };

        let snapshot = table::borrow_mut(snapshots, senderAddr);
        if(!dynamic_field::exists_(&snapshot.id, typeName)){
            dynamic_field::add(&mut snapshot.id, typeName, vector::empty<Coin<TOKEN>>())
        };

        //stake asset
        let assetBranch = dynamic_field::borrow_mut(&mut snapshot.id, typeName);
        vector::push_back(assetBranch, joinedToken);
        snapshot.total_object = snapshot.total_object + 1;

        //update power
        let powerConfig = table::borrow(tokenBoost, typeName);
        common::increaseTable(powers, senderAddr, tokenVal * powerConfig.factor);
    }

    ///unstake asset, power reduced
    public fun unsnapshotToken<TOKEN>(dao: &mut Dao,
                                      version: &mut Version,
                                      ctx: &mut TxContext){
        checkVersion(version, VERSION);
        let senderAddr = sender(ctx);
        let snapshots = &mut dao.asset_snapshot;
        let nftBoost = &mut dao.nft_boost;
        let powers = &mut dao.powers;

        let snapshot = table::borrow_mut(snapshots, senderAddr);
        let typeName = type_name::get<TOKEN>();

        //withdraw all asset branch
        let assetBranch = dynamic_field::remove<TypeName, vector<Coin<TOKEN>>>(&mut snapshot.id, typeName);
        let assetSize = vector::length(&assetBranch);
        let assetVal = common::totalValue(&assetBranch);

        common::transferAssetVector(assetBranch, senderAddr);

        //reduce power
        snapshot.total_object = snapshot.total_object - assetSize;
        let powerConfig = table::borrow(nftBoost, typeName);
        common::decreaseTable(powers, senderAddr, assetVal * powerConfig.factor);

        if(snapshot.total_object == 0){
            destroyAssetSnapshot(table::remove(snapshots, senderAddr));
            table::remove(powers, senderAddr);
        };
    }

    fun getVotingPower(user: address, dao: &Dao): u64 {
        if(table::contains(&dao.powers, user)) {
            *table::borrow(&dao.powers, user)
        }
        else {
            0u64
        }
    }

     fun getTokenBoostFactor<TOKEN>(dao: &Dao): u64{
        table::borrow(&dao.token_boost, type_name::get<TOKEN>()).factor
    }

     fun getNftBoostFactor<NFT>(dao: &Dao): u64 {
       table::borrow(&dao.nft_boost, type_name::get<NFT>()).factor
    }

    fun destroyAssetSnapshot(snap: AssetSnapshot){
        assert!(snap.total_object == 0, ERR_SNAPSHOT_NOT_EMPTY);
        let AssetSnapshot{
            id,
            total_object: _total_object,
        } = snap;

        object::delete(id);
    }

    fun validateRole(roleCap: &DaoRoleCap, minRole: u8, dao: &Dao, sclock: &Clock){
        let daoId = id_address(dao);
        let timestamp_ms = clock::timestamp_ms(sclock);
        assert!(roleCap.dao == daoId
            && roleCap.role >= minRole
            && (roleCap.expire_time == 0 || (timestamp_ms <= roleCap.expire_time)),
            ERR_PERMISSION);
    }

    fun validatePropVsDao(dao: &Dao, prop: &Proposal){
        assert!(table::contains(&dao.proposals, id_address(prop))
            && (prop.dao == id_address(dao)) ,
            ERR_INVALID_PARAMS);
    }

    fun validatePropState2Vote(sclock: &Clock, prop: &Proposal){
        let now_ms = clock::timestamp_ms(sclock);
        assert!(prop.state == PROP_STATE_PENDING
            &&(now_ms < prop.expire)
            && prop.type == PROPOSAL_TYPE_ONCHAIN ,
            ERR_INVALID_STATE);
    }

    fun validateNftVoteWhitelisted<NFT: key + store>(dao: &Dao){
        assert!(table::contains(&dao.nft_boost, type_name::get<NFT>()), ERR_NOT_WHITELISTED);
    }

    fun validateTokenVoteWhitelisted<TOKEN>(dao: &Dao){
        assert!(table::contains(&dao.nft_boost, type_name::get<TOKEN>()), ERR_NOT_WHITELISTED);
    }

    fun validatePropOwner(prop: &Proposal, ctx: &TxContext){
        assert!(prop.owner == sender(ctx), ERR_PERMISSION);
    }
}
