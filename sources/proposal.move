module gize::proposal {
    use sui::object::{UID, id_address};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::{public_share_object, share_object};
    use sui::object;
    use sui::table::Table;
    use sui::table;
    use sui::coin::Coin;
    use sui::coin;
    use sui::clock::Clock;
    use sui::clock;
    use sui::event::emit;
    use std::vector;
    use sui::vec_map::VecMap;
    use sui::vec_map;
    use gize::version::{Version, checkVersion};
    use gize::common::transferVector;
    use gize::config::AdminCap;
    use sui::math;
    use gize::common;
    use sui::math::min;
    use std::type_name::TypeName;
    use std::type_name;
    use sui::dynamic_field;
    use sui::pay;

    struct PROPOSAL has drop {}

    const VERSION: u64 = 1;

    const ONE_UNDRED_SCALED_10000: u64 = 10000;
    const MAX_CHOICES: u8 = 100;

    const ERR_INVALID_ADMIN: u64 = 1001;
    const ERR_INVALID_STATE: u64 = 1002;
    const ERR_INVALID_CHOICE: u64 = 1003;
    const ERR_PROPOSAL_NOT_FOUND: u64 = 1004;
    const ERR_INVALID_PARAMS: u64 = 1005;
    const ERR_NOT_ENOUGHT_POWER: u64 = 1006;
    const ERR_INVALID_TOKEN_NFT: u64 = 1007;
    const ERR_ALREADY_VOTED: u64 = 1008;
    const ERR_NOT_VOTED: u64 = 1009;
    const ERR_INVALID_EXPIRE_TIME: u64 = 1010;
    const ERR_OPERATOR_EXPIRED: u64 = 1011;
    const ERR_ACCESS_DENIED: u64 = 1012;

    const ERR_ASSET_EXIST: u64 = 2001;
    const ERR_SNAPSHOT_RUNNING: u64 = 2002;

    const PROPOSAL_TYPE_ONCHAIN: u8 = 1;  //on chain, ready for voting
    const PROPOSAL_TYPE_OFFCHAIN: u8 = 2; //off chain, no need to vote

    const PROPOSAL_VOTE_TYPE_SINGLE: u8 = 1;  //choose one only
    const PROPOSAL_VOTE_TYPE_MULTI_WEIGHT: u8 = 2; //choose multiple with weighted allocation

    const PROPOSAL_STATE_PENDING: u8 = 1;
    const PROPOSAL_STATE_APPROVED: u8 = 2;
    const PROPOSAL_STATE_REJECTED: u8 = 3;

    //  !SNAPSHOT
    struct AssetSnapshot has key, store {
        id: UID,
        total_object: u64
        //dynamic filed of TypeName > vector<AssetType>
    }

    struct BoostConfig has drop, store, copy {
        boost_factor: u64   //power factor, for example: NFT size * power_factor
    }

    struct OperatorConfig has drop, store, copy {
        expire: u64, //expire timestamp
        boost_factor: u64 //power factor per operator
    }

    struct DaoConfig has key, store {
        id: UID,
        anonymous_boost: BoostConfig,   //anonymous boost
        nft_boost: Table<TypeName, BoostConfig>,   //nft whitelist you can stake
        token_boost: Table<TypeName, BoostConfig>,  //token whitelist you can stake
        operators: Table<address, OperatorConfig>,  //operator roles
        powers: Table<address, u64>, //user power
        asset_snapshot: Table<address, AssetSnapshot>, //snapshot of asset
        threshold_operator: u64,    //minimum power allowed for operator to make proposal
        threshold_snapshot: u64,    //minimum power allowed for operator to make proposal
    }

    //  !PROPOSALS
    struct Choice has drop, copy, store {
        code: u8,
        name: vector<u8>, //string name, ex: YES|NO, OPTION1|OPTION2|OPTION3
        total_vote: u64, //in voting power
        threshold: u64 //in voting power, decide whether the choice is passed ?
    }

    struct UserVote has drop, copy, store {
        power: u64,
        choices: vector<u8>,
        choice_values: vector<u64>,
    }

    const PROP_STATE_INIT:u8 = 1;
    const PROP_STATE_PENDING:u8 = 2;
    const PROP_STATE_APPROVED:u8 = 3;
    const PROP_STATE_REJECTED:u8 = 4;
    const PROP_STATE_DELISTED:u8 = 5;

    struct Proposal has key, store {
        id: UID,
        owner: address,
        dao: address,
        state: u8,
        name: vector<u8>,
        description: vector<u8>,
        thread_link: vector<u8>, //offchain discussion
        type: u8, //on chain| off chain
        vote_power_threshold: u64, //minimum power allowed to vote
        vote_type: u8, //single | multiple weighted. multiple equally is one special case of multiple weighted
        choices: VecMap<u8, Choice>, //fore example: code -> Choice!
        user_votes: Table<address, UserVote>, //cache user votes, to prevent double votes, support revoking votes
        expire: u64, //expired timestamp
    }

    struct Dao has key, store {
        id: UID,
        config: DaoConfig,
        proposals: Table<address, u8>
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
        total_users: u64
    }

    struct ProposalVotedEvent has copy, drop {
        id: address,
        user_vote: UserVote
    }

    struct ProposalUnVotedEvent has copy, drop {
        id: address,
        user_vote: UserVote
    }

    struct ProposalChoiceAddedEvent has copy, drop {
        id: address,
        choice: Choice
    }

    public fun createDao(_admin: &AdminCap,
                         version: &mut Version,
                         ctx: &mut TxContext){
        checkVersion(version, VERSION);
        public_share_object(Dao {
            id: object::new(ctx),
            config: DaoConfig {
                id: object::new(ctx),
                anonymous_boost: BoostConfig {
                    boost_factor: 0,
                },
                operators: table::new(ctx),
                nft_boost: table::new(ctx),
                token_boost: table::new(ctx),
                powers: table::new(ctx),
                asset_snapshot: table::new(ctx),
                threshold_operator: 0,
                threshold_snapshot: 0,
            },
            proposals: table::new(ctx)
        });
    }

    public fun submitProposalByOperator(name: vector<u8>,
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
                                        version: &mut Version,
                                        ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        let senderAddr = sender(ctx);
        assert!(isOperatorWhitelisted(&dao.config, senderAddr), ERR_ACCESS_DENIED);

        let (factor, opExpire) = getOperatorBoostFactors(&dao.config, senderAddr);
        assert!(opExpire > clock::timestamp_ms(sclock), ERR_OPERATOR_EXPIRED);

        let power = factor;
        assert!( power >= getThresholdOperator(&dao.config) , ERR_ACCESS_DENIED);

        submitProposal(name, description, threadLink, type, votePowerThreshold,
            voteType, expire, choiceCodes, choiceNames, choiceThresholds, dao, sclock, ctx);
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
                                            choiceThresholds: vector<u64>,
                                            dao: &mut Dao,
                                            token: &Coin<TOKEN>,
                                            sclock: &Clock,
                                            version: &mut Version,
                                            ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        let daoConfig = &dao.config;
        assert!(isTokenVoteWhitelisted<TOKEN>(daoConfig), ERR_ACCESS_DENIED);

        let factor = getTokenBoostFactor<TOKEN>(daoConfig);
        let power = factor * coin::value(token);
        assert!( power >= getThresholdSnapshot(daoConfig) , ERR_ACCESS_DENIED);
        submitProposal(name, description, threadLink, type, votePowerThreshold,
            voteType, expire, choiceCodes, choiceNames, choiceThresholds, dao, sclock, ctx);
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
                                                      choiceThresholds: vector<u64>,
                                                      dao: &mut Dao,
                                                      sclock: &Clock,
                                                      nfts: vector<NFT>,
                                                      version: &mut Version,
                                                      ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let daoConfig = &dao.config;
        assert!(isNftVoteWhitelisted<NFT>(daoConfig), ERR_ACCESS_DENIED);

        let factor= getTokenBoostFactor<NFT>(daoConfig);
        let power = factor * vector::length(&nfts);

        assert!( power >= getThresholdSnapshot(daoConfig) , ERR_ACCESS_DENIED);

        submitProposal(name, description, threadLink, type, votePowerThreshold,
            voteType, expire, choiceCodes, choiceNames, choiceThresholds, dao, sclock, ctx);

        //CRITICAL: transfer back to owner
        transferVector(nfts, sender(ctx));
    }

    public fun submitProposalByPower(name: vector<u8>,
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
                                     version: &mut Version,
                                     ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let daoConfig = &dao.config;
        let power = getVotingPower(sender(ctx), daoConfig);
        assert!( power >= getThresholdSnapshot(daoConfig) , ERR_ACCESS_DENIED);

        submitProposal(name, description, threadLink, type, votePowerThreshold,
            voteType, expire, choiceCodes, choiceNames, choiceThresholds, dao, sclock, ctx);
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
                       choice_thresholds: vector<u64>,
                       dao: &mut Dao,
                       sclock: &Clock,
                       ctx: &mut TxContext){

        assert!(vector::length(&description) > 0
                && vector::length(&threadLink) > 0
                && (type == PROPOSAL_TYPE_ONCHAIN || type == PROPOSAL_TYPE_OFFCHAIN)
                && (voteType == PROPOSAL_VOTE_TYPE_SINGLE || voteType == PROPOSAL_VOTE_TYPE_MULTI_WEIGHT)
                && expire > clock::timestamp_ms(sclock)
                && vector::length(&choiceCodes) > 0
                &&(vector::length(&choiceCodes) == vector::length(&choice_names))
                && (vector::length(&choiceCodes) == vector::length(&choice_thresholds)),
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
            expire
        };

        while (!vector::is_empty(&choiceCodes)){
            addProposalChoice(vector::pop_back(&mut choiceCodes),
                        vector::pop_back(&mut choice_names),
                    vector::pop_back(&mut choice_thresholds),
            &mut prop);
        };

        let propId = id_address(&prop);

        let event = ProposalSubmittedEvent {
            id: propId,
            state: prop.state,
            name,
            description,
            thread_link: threadLink,
            type,
            vote_power_threshold: votePowerThreshold,
            vote_type: voteType,
            expire
        };

        table::add(&mut dao.proposals, id_address(&prop), prop.state);

        //share the prop
        share_object(prop);

        emit(event)
    }

    fun addProposalChoice(code: u8,
                           name: vector<u8>,
                           threshold: u64,
                           prop: &mut Proposal){
        assert!((code < MAX_CHOICES)
                && vector::length(&name) > 0
                && threshold > 0
                && vec_map::contains(&mut prop.choices, &code)
                , ERR_INVALID_CHOICE);

        if(vec_map::contains(&mut prop.choices, &code)){
            let choice = vec_map::get_mut(&mut prop.choices, &code);
            choice.name = name;
            choice.threshold  = threshold;
            choice.total_vote = 0;
        } else{
            let choice =  Choice {
                code,
                name,
                total_vote: 0u64,
                threshold
            };

            vec_map::insert(&mut prop.choices, code, choice);
        };
    }

    public fun listProposal(prop: &mut Proposal,
                            sclock: &Clock,
                            version: &mut Version,
                            ctx: &mut TxContext){
        checkVersion(version, VERSION);
        let propId = id_address(prop);
        assert!(prop.owner == sender(ctx), ERR_ACCESS_DENIED);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        assert!(vec_map::size(&prop.choices) > 0 && clock::timestamp_ms(sclock) < prop.expire, ERR_INVALID_PARAMS);
        prop.state  = PROP_STATE_PENDING;

        emit(ProposalListedEvent {
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
        })
    }

    public fun delistProposal(prop: Proposal,
                                dao: &mut Dao,
                                version: &mut Version,
                                ctx: &mut TxContext){
        checkVersion(version, VERSION);
        let propId = id_address(&prop);
        let daoId = id_address(dao);
        assert!(table::contains(&dao.proposals, propId)
            && (prop.dao == daoId), ERR_INVALID_PARAMS);

        assert!(prop.owner == sender(ctx), ERR_ACCESS_DENIED);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        prop.state  = PROP_STATE_DELISTED;

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
                                   choiceValues: vector<u64>,
                                   powerUsed: u64,
                                   sclock: &Clock,
                                   version: &mut Version,
                                   ctx: &mut TxContext){
        checkVersion(version, VERSION);
        let propId = id_address(prop);
        let daoId = id_address(dao);

        //validate params
        assert!(table::contains(&dao.proposals, propId)
            && (prop.dao == daoId) , ERR_INVALID_PARAMS);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN , ERR_INVALID_STATE);

        //valid choices ?
        assert!(vector::length(&choices) == vector::length(&choiceValues) && vector::length(&choices) > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let daoConfig = &dao.config;
        //in-the case have no power, act as anonymous
        let power = math::max(getVotingPower(sender(ctx), daoConfig), daoConfig.anonymous_boost.boost_factor);
        power = math::min(power, powerUsed);
        let userVote = distributeVote(prop, choices, choiceValues, power, ctx);

        //event
        emit(ProposalVotedEvent {
            id: propId,
            user_vote: userVote
        })
    }

    ///
    /// Directly vote by coin list
    ///
    public fun voteByCoin<TOKEN: key + store>(prop: &mut Proposal,
                                              dao: &mut Dao,
                                              choices: vector<u8>,
                                              choice_values: vector<u64>,
                                              coins: vector<Coin<TOKEN>>,
                                              powerUsed: u64,
                                              sclock: &Clock,
                                              version: &mut Version,
                                              ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        let totalVal = common::totalValue(&coins);
        assert!(totalVal > 0, ERR_INVALID_PARAMS);

        let propId = id_address(prop);
        let daoId = id_address(dao);
        assert!(table::contains(&dao.proposals, propId)
            && (prop.dao == daoId) , ERR_INVALID_PARAMS);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN , ERR_INVALID_STATE);

        let daoConfig = &dao.config;

        //whitelisted ?
        assert!(isTokenVoteWhitelisted<TOKEN>(daoConfig), ERR_INVALID_TOKEN_NFT);

        //valid choices ?
        assert!(vector::length(&choices) == vector::length(&choice_values) && vector::length(&choices) > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let factor = getTokenBoostFactor<TOKEN>(daoConfig);
        let power = factor * totalVal;
        power = min(power, powerUsed);

        //transfer back
        common::transferVector(coins, sender(ctx));

        let userVote = distributeVote(prop, choices, choice_values, power, ctx);

        //event
        emit(ProposalVotedEvent {
            id: propId,
            user_vote: userVote
        })
    }


    ///
    /// Directly vote by NFT collection
    ///
    public fun voteByNfts<NFT: key + store>(prop: &mut Proposal,
                                            dao: &mut Dao,
                                            choices: vector<u8>,
                                            choice_values: vector<u64>,
                                            nfts: vector<NFT>,
                                            powerUsed: u64,
                                            sclock: &Clock,
                                            version: &mut Version,
                                            ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        let propId = id_address(prop);
        let daoId = id_address(dao);
        assert!(table::contains(&dao.proposals, propId)
            && (prop.dao == daoId) , ERR_INVALID_PARAMS);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN, ERR_INVALID_STATE);

        //white listed ?
        let daoConfig = &dao.config;
        assert!(isNftVoteWhitelisted<NFT>(daoConfig), ERR_INVALID_TOKEN_NFT);

        assert!(vector::length(&choices) == vector::length(&choice_values) && vector::length(&choices) > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let factor = getNftBoostFactor<NFT>(daoConfig);
        let power = math::min(powerUsed, factor * vector::length(&nfts));
        let userVote = distributeVote(prop, choices, choice_values, power, ctx);

        //return nfts
        transferVector(nfts, sender(ctx));

        //event
        emit(ProposalVotedEvent {
            id: propId,
            user_vote: userVote
        })
    }

    public fun unvote(prop: &mut Proposal,
                      dao: &mut Dao,
                      sclock: &Clock,
                      version: &mut Version,
                      ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        let propId = id_address(prop);
        let daoId = id_address(dao);
        assert!(table::contains(&dao.proposals, propId)
            && (prop.dao == daoId) , ERR_INVALID_PARAMS);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(prop.state == PROP_STATE_PENDING && (now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN, ERR_INVALID_STATE);

        let senderAddr = sender(ctx);
        assert!(table::contains(&prop.user_votes, senderAddr), ERR_NOT_VOTED);

        let userVote = table::borrow(&prop.user_votes, senderAddr);
        let choices = &userVote.choices;
        let choice_values = &userVote.choice_values;
        let power = userVote.power;

        //now distribute vote
        if(prop.vote_type == PROPOSAL_VOTE_TYPE_SINGLE){
            //allocate all power to single choice
            assert!(vector::length(choices) == 1, ERR_INVALID_PARAMS);
            let choiceType = *vector::borrow(choices, 0);
            let _choiceValue = *vector::borrow(choice_values, 0); //ignore because all power will focus on one choice!
            let choice = vec_map::get_mut(&mut prop.choices, &choiceType);
            choice.total_vote = choice.total_vote - power;
        }
        else  if(prop.vote_type == PROPOSAL_VOTE_TYPE_MULTI_WEIGHT){
            //allocate to multi choices: how many percent scaled of power amount allocated for each type ?
            let index = 0;
            while (index < vector::length(choices)){
                let choiceType = *vector::borrow(choices, index);
                let choiceValue = *vector::borrow(choice_values, index);
                let choice = vec_map::get_mut(&mut prop.choices, &choiceType);
                let subPower = choiceValue * power /ONE_UNDRED_SCALED_10000;
                choice.total_vote  = choice.total_vote - subPower;
                index = index + 1;
            };
        };

        //remove
        let userVote = table::remove(&mut prop.user_votes, senderAddr);

        //event
        emit(ProposalUnVotedEvent{
            id: propId,
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

        assert!(sender(ctx) == prop.owner, ERR_ACCESS_DENIED);

        //validate params
        let propId = id_address(prop);
        let daoId = id_address(dao);
        assert!(table::contains(&dao.proposals, propId)
            && (prop.dao == daoId) , ERR_INVALID_PARAMS);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(prop.state == PROP_STATE_PENDING && (now_ms >= prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN, ERR_INVALID_STATE);

        //finalize state, what is success ?
        let choices = &mut prop.choices;
        let passed = true;
        let index = 0;
        while (index < vec_map::size(choices)){
            let (_key, choice) = vec_map::get_entry_by_idx<u8, Choice>(choices, index);
            passed = passed && (choice.total_vote >= choice.threshold);
            if(!passed)
                break ;
        };

        //state
        prop.state = if(passed) { PROP_STATE_APPROVED } else { PROP_STATE_REJECTED };

        //event
        emit(ProposalFinalizedEvent {
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
            total_users: table::length(&prop.user_votes)
        })
    }

    fun distributeVote(prop: &mut Proposal,
                       choices: vector<u8>,
                       choice_values: vector<u64>,
                       power: u64,
                       ctx: &mut TxContext): UserVote {
        //make sure not voted
        let senderAddr = sender(ctx);
        assert!(!table::contains(&prop.user_votes, senderAddr), ERR_ALREADY_VOTED);

        //threshold power
        assert!(power >= prop.vote_power_threshold, ERR_NOT_ENOUGHT_POWER);

        //now distribute vote
        if(prop.vote_type == PROPOSAL_VOTE_TYPE_SINGLE){
            //allocate all power to single choice
            assert!(vector::length(&choices) == 1, ERR_INVALID_PARAMS);
            let choiceType = *vector::borrow(&choices, 0);
            let _choiceValue = *vector::borrow(&choice_values, 0); //ignore because all power will focus on one choice!
            let choice = vec_map::get_mut(&mut prop.choices, &choiceType);
            choice.total_vote = choice.total_vote + power;
        }
        else  if(prop.vote_type == PROPOSAL_VOTE_TYPE_MULTI_WEIGHT){
            //allocate to multi choices: how many percent scaled of power amount allocated for each type ?
            let sum = 0;
            let index = 0;
            while (index < vector::length(&choices)){
                let choiceType = *vector::borrow(&choices, index);
                let choiceValue = *vector::borrow(&choice_values, index);
                let choice = vec_map::get_mut(&mut prop.choices, &choiceType);
                let subPower = choiceValue * power /ONE_UNDRED_SCALED_10000;
                choice.total_vote  = choice.total_vote + subPower;
                sum = sum + choiceValue;
                index = index + 1;
            };
            assert!(sum <= ONE_UNDRED_SCALED_10000, ERR_INVALID_PARAMS);
        };

        //mark user voted
        let userVote = UserVote {
            power,
            choices,
            choice_values
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
            expire:_expire
        } = prop;

        object::delete(id);
        table::drop(user_votes);
    }

    public fun setThreshold(_admin: &AdminCap,
                            operatorThreshold: u64,
                            snapshotThreshold: u64,
                            dao: &mut Dao,
                            version: &mut Version){
        checkVersion(version, VERSION);

        dao.config.threshold_operator = operatorThreshold;
        dao.config.threshold_snapshot = snapshotThreshold;
    }

    public fun addDaoOperator(_admin: &AdminCap,
                              operatorAddr: address,
                              expireTime: u64,
                              boostFactor: u64,
                              dao: &mut Dao,
                              sclock: &Clock,
                              version: &mut Version){
        checkVersion(version, VERSION);
        assert!(table::length(&dao.config.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);

        assert!(expireTime > clock::timestamp_ms(sclock), ERR_INVALID_PARAMS);
        let daoOps = &mut dao.config.operators;
        if(table::contains(daoOps, operatorAddr)){
            let config = table::borrow_mut(daoOps, operatorAddr);
            config.expire = expireTime;
            config.boost_factor = boostFactor;
        }
        else{
            table::add(daoOps, operatorAddr, OperatorConfig {
                boost_factor: boostFactor,
                expire: expireTime
            })
        }
    }

    ///@todo make sure that no asset staked on this config while updating config
    public fun setAnonymousBoost(_adminCap: &AdminCap,
                                 power_factor: u64,
                                 dao: &mut Dao,
                                 version: &mut Version){
        checkVersion(version, VERSION);
        assert!(table::length(&dao.config.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);

        assert!(table::length(&dao.config.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);
        dao.config.anonymous_boost = BoostConfig {
            boost_factor: power_factor,
        };
    }

    public fun setNftBoost<NFT: key + store>(_adminCap: &AdminCap,
                                             power_factor: u64,
                                             dao: &mut Dao,
                                             version: &mut Version){
        checkVersion(version, VERSION);
        assert!(table::length(&dao.config.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);

        let typeName = type_name::get<NFT>();
        if(table::contains(&dao.config.nft_boost, typeName)){
            table::remove(&mut dao.config.nft_boost, typeName);
        };

        table::add(&mut dao.config.nft_boost, typeName, BoostConfig {
            boost_factor: power_factor,
        });
    }

    public fun setTokenBoost<TOKEN>(_adminCap: &AdminCap,
                                    boostFactor: u64,
                                    dao: &mut Dao,
                                    version: &mut Version){
        checkVersion(version, VERSION);
        assert!(table::length(&dao.config.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);

        let typeName = type_name::get<TOKEN>();
        let tokenBoost = &mut dao.config.token_boost;
        if(table::contains(tokenBoost, typeName)){
            table::remove(tokenBoost, typeName);
        };

        table::add(&mut dao.config.token_boost, typeName, BoostConfig {
            boost_factor: boostFactor,
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
            && table::contains(&dao.config.nft_boost, typeName)
            && table::borrow(&dao.config.nft_boost, typeName).boost_factor > 0,
            ERR_INVALID_PARAMS);
        let senderAddr = sender(ctx);

        //init snapshot bag
        if(!table::contains(&mut dao.config.asset_snapshot, senderAddr)){
            table::add(&mut dao.config.asset_snapshot, senderAddr, AssetSnapshot {
                id: object::new(ctx),
                total_object: 0
            })
        };

        let snapshot = table::borrow_mut(&mut dao.config.asset_snapshot, senderAddr);
        if(!dynamic_field::exists_(&snapshot.id, typeName)){
            dynamic_field::add(&mut snapshot.id, typeName, vector::empty<NFT>())
        };

        //stake asset
        let assetBranch = dynamic_field::borrow_mut<TypeName, vector<NFT>>(&mut snapshot.id, typeName);
        vector::append(assetBranch, nfts);
        snapshot.total_object = snapshot.total_object + nftSize;

        //update power
        let powerConfig = table::borrow(&dao.config.nft_boost, typeName);
        common::increaseTable(&mut dao.config.powers, senderAddr, nftSize * powerConfig.boost_factor);
    }

    /// Unstake asset, power reduced
    public fun unsnapshotNft<NFT: key + store>(dao: &mut Dao,
                                               version: &mut Version,
                                               ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate
        let senderAddr = sender(ctx);
        let snapshots = &mut dao.config.asset_snapshot;
        let nftBoost = &mut dao.config.nft_boost;
        let powers = &mut dao.config.powers;

        assert!(table::contains(snapshots, senderAddr), ERR_INVALID_PARAMS);
        let snapshot = table::borrow_mut(snapshots, senderAddr);
        let typeName = type_name::get<NFT>();
        assert!(dynamic_field::exists_(&snapshot.id, typeName), ERR_INVALID_PARAMS);

        //withdraw all asset branch
        let assetBranch = dynamic_field::remove<TypeName, vector<NFT>>(&mut snapshot.id, typeName);
        let nftSize = vector::length(&assetBranch);
        transferVector(assetBranch, senderAddr);

        //reduce power
        snapshot.total_object = snapshot.total_object - nftSize;
        let powerConfig = table::borrow(nftBoost, typeName);
        common::decreaseTable(powers, senderAddr, nftSize* powerConfig.boost_factor);

        if(snapshot.total_object == 0){
            destroyAssetSnapshot(table::remove(snapshots, senderAddr));
            table::remove(&mut dao.config.powers, senderAddr);
        };
    }

    ///stake asset to get more power
    public fun snapshotToken<TOKEN>(tokens: vector<Coin<TOKEN>>,
                                    dao: &mut Dao,
                                    version: &mut Version,
                                    ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let tokenSize =  vector::length(&tokens);
        let typeName = type_name::get<TOKEN>();

        let snapshots = &mut dao.config.asset_snapshot;
        let tokenBoost = &mut dao.config.token_boost;
        let powers = &mut dao.config.powers;

        //validate
        assert!(tokenSize > 0
            && table::contains(tokenBoost, typeName)
            && table::borrow(tokenBoost, typeName).boost_factor > 0,
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
        let assetBranch = dynamic_field::borrow_mut<TypeName, vector<Coin<TOKEN>>>(&mut snapshot.id, typeName);
        vector::push_back(assetBranch, joinedToken);
        snapshot.total_object = snapshot.total_object + 1;

        //update power
        let powerConfig = table::borrow(tokenBoost, typeName);
        common::increaseTable(powers, senderAddr, tokenVal * powerConfig.boost_factor);
    }

    ///unstake asset, power reduced
    public fun unsnapshotToken<TOKEN>(dao: &mut Dao,
                                      version: &mut Version,
                                      ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate
        let senderAddr = sender(ctx);

        let snapshots = &mut dao.config.asset_snapshot;
        let nftBoost = &mut dao.config.nft_boost;
        let powers = &mut dao.config.powers;

        assert!(table::contains(snapshots, senderAddr), ERR_INVALID_PARAMS);
        let snapshot = table::borrow_mut(snapshots, senderAddr);
        let typeName = type_name::get<TOKEN>();
        assert!(dynamic_field::exists_(&snapshot.id, typeName), ERR_INVALID_PARAMS);

        //withdraw all asset branch
        let assetBranch = dynamic_field::remove<TypeName, vector<Coin<TOKEN>>>(&mut snapshot.id, typeName);
        let tokenSize = vector::length(&assetBranch);
        let tokenVal = common::totalValue(&assetBranch);

        common::transferVector(assetBranch, senderAddr);

        //reduce power
        snapshot.total_object = snapshot.total_object - tokenSize;
        let powerConfig = table::borrow(nftBoost, typeName);
        common::decreaseTable(powers, senderAddr, tokenVal * powerConfig.boost_factor);

        if(snapshot.total_object == 0){
            destroyAssetSnapshot(table::remove(snapshots, senderAddr));
            table::remove(powers, senderAddr);
        };
    }

    ///show voting power
    /// @todo optimize
    fun getVotingPower(user: address, daoConfig: &DaoConfig): u64 {
        if(table::contains(&daoConfig.powers, user)) {
            *table::borrow(&daoConfig.powers, user)
        }
        else {
            0u64
        }
    }

     fun isNftVoteWhitelisted<NFT: key + store>(daoConfig: &DaoConfig): bool{
        table::contains(&daoConfig.nft_boost, type_name::get<NFT>())
    }

     fun isTokenVoteWhitelisted<TOKEN>(daoConfig: &DaoConfig): bool{
        table::contains(&daoConfig.nft_boost, type_name::get<TOKEN>())
    }

     fun getTokenBoostFactor<TOKEN>(daoConfig: &DaoConfig): u64{
        let config = table::borrow(&daoConfig.token_boost, type_name::get<TOKEN>());
        config.boost_factor
    }

     fun getThresholdSnapshot(daoConfig: &DaoConfig): u64{
        daoConfig.threshold_snapshot
    }

     fun getThresholdOperator(daoConfig: &DaoConfig): u64{
        daoConfig.threshold_operator
    }

     fun getNftBoostFactor<NFT>(daoConfig: &DaoConfig): u64 {
        let config = table::borrow(&daoConfig.nft_boost, type_name::get<NFT>());
        config.boost_factor
    }

     fun isOperatorWhitelisted(daoConfig: &DaoConfig, operatorAddr: address): bool{
        table::contains(&daoConfig.operators, operatorAddr)
    }

    public fun getOperatorBoostFactors(daoConfig: &DaoConfig, operatorAddr: address): (u64, u64){
        let config = table::borrow(&daoConfig.operators, operatorAddr);
        (config.boost_factor, config.expire)
    }

    public fun getAnonymousBoostFactor(daoConfig: &DaoConfig): u64 {
        let config = daoConfig.anonymous_boost;
        config.boost_factor
    }

    //@fixme review remove dynamic object
    fun destroyAssetSnapshot(snap: AssetSnapshot){
        let AssetSnapshot{
            id,
            total_object: _total_object,
        } = snap;

        object::delete(id);
    }
}
