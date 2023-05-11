module gize::proposal {
    use sui::object::{UID, id_address};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::{public_share_object};
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
    use gize::snapshot::DaoSnapshotConfig;
    use gize::snapshot;
    use gize::common::transferVector;
    use gize::config::AdminCap;

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

    const PROPOSAL_TYPE_ONCHAIN: u8 = 1;  //on chain, ready for voting
    const PROPOSAL_TYPE_OFFCHAIN: u8 = 2; //off chain, no need to vote

    const PROPOSAL_VOTE_TYPE_SINGLE: u8 = 1;  //choose one only
    const PROPOSAL_VOTE_TYPE_MULTI_WEIGHT: u8 = 2; //choose multiple with weighted allocation

    const PROPOSAL_STATE_PENDING: u8 = 1;
    const PROPOSAL_STATE_APPROVED: u8 = 2;
    const PROPOSAL_STATE_REJECTED: u8 = 3;

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
        proposals: Table<address, Proposal>
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
            proposals: table::new(ctx)
        });
    }

    public fun submitProposalByAdmin(_admin: &AdminCap,
                                     name: vector<u8>,
                                     description: vector<u8>,
                                     thread_link: vector<u8>,
                                     type: u8,
                                     vote_type: u8,
                                     token_condition_threshold: u64,
                                     expire: u64,
                                     choice_codes: vector<u8>,
                                     choice_names: vector<vector<u8>>,
                                     choice_thresholds: vector<u64>,
                                     dao: &mut Dao,
                                     sclock: &Clock,
                                     version: &mut Version,
                                     ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        submitProposal(name, description, thread_link, type, token_condition_threshold,
            vote_type, expire, choice_codes, choice_names, choice_thresholds, dao, sclock, ctx);
    }

    public fun submitProposalByOperator(name: vector<u8>,
                                        description: vector<u8>,
                                        thread_link: vector<u8>,
                                        type: u8,
                                        vote_power_threshold: u64,
                                        vote_type: u8,
                                        expire: u64,
                                        choice_codes: vector<u8>,
                                        choice_names: vector<vector<u8>>,
                                        choice_thresholds: vector<u64>,
                                        dao: &mut Dao,
                                        snapshotReg: &DaoSnapshotConfig,
                                        sclock: &Clock,
                                        version: &mut Version,
                                        ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        let senderAddr = sender(ctx);
        assert!(snapshot::isOperatorWhitelisted(snapshotReg, senderAddr), ERR_ACCESS_DENIED);

        let (factor, opExpire) = snapshot::getOperatorBoostFactors(snapshotReg, senderAddr);
        assert!(opExpire > clock::timestamp_ms(sclock), ERR_OPERATOR_EXPIRED);

        let power = factor;
        assert!( power >= snapshot::getThresholdOperator(snapshotReg) , ERR_ACCESS_DENIED);

        submitProposal(name, description, thread_link, type, vote_power_threshold,
            vote_type, expire, choice_codes, choice_names, choice_thresholds, dao, sclock, ctx);
    }

    public fun submitProposalByToken<TOKEN>(name: vector<u8>,
                                            description: vector<u8>,
                                            thread_link: vector<u8>,
                                            type: u8,
                                            vote_power_threshold: u64,
                                            vote_type: u8,
                                            expire: u64,
                                            choice_codes: vector<u8>,
                                            choice_names: vector<vector<u8>>,
                                            choice_thresholds: vector<u64>,
                                            dao: &mut Dao,
                                            token: &Coin<TOKEN>,
                                            snapshotReg: &DaoSnapshotConfig,
                                            sclock: &Clock,
                                            version: &mut Version,
                                            ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        assert!(snapshot::isTokenVoteWhitelisted<TOKEN>(snapshotReg), ERR_ACCESS_DENIED);

        let factor = snapshot::getTokenBoostFactor<TOKEN>(snapshotReg);
        let power = factor * coin::value(token);
        assert!( power >= snapshot::getThresholdSnapshot(snapshotReg) , ERR_ACCESS_DENIED);
        submitProposal(name, description, thread_link, type, vote_power_threshold,
            vote_type, expire, choice_codes, choice_names, choice_thresholds, dao, sclock, ctx);
    }

    public fun submitProposalByNfts<NFT: key + store>(name: vector<u8>,
                                                      description: vector<u8>,
                                                      thread_link: vector<u8>,
                                                      type: u8,
                                                      vote_power_threshold: u64,
                                                      vote_type: u8,
                                                      expire: u64,
                                                      choice_codes: vector<u8>,
                                                      choice_names: vector<vector<u8>>,
                                                      choice_thresholds: vector<u64>,
                                                      dao: &mut Dao,
                                                      sclock: &Clock,
                                                      nfts: vector<NFT>,
                                                      snapshotReg: &DaoSnapshotConfig,
                                                      version: &mut Version,
                                                      ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        assert!(snapshot::isNftVoteWhitelisted<NFT>(snapshotReg), ERR_ACCESS_DENIED);

        let factor= snapshot::getTokenBoostFactor<NFT>(snapshotReg);
        let power = factor * vector::length(&nfts);
        assert!( power >= snapshot::getThresholdSnapshot(snapshotReg) , ERR_ACCESS_DENIED);

        submitProposal(name, description, thread_link, type, vote_power_threshold,
            vote_type, expire, choice_codes, choice_names, choice_thresholds, dao, sclock, ctx);

        //CRITICAL: transfer back to owner
        transferVector(nfts, sender(ctx));
    }

    public fun submitProposalByPower(name: vector<u8>,
                                          description: vector<u8>,
                                          thread_link: vector<u8>,
                                          type: u8,
                                          vote_power_threshold: u64,
                                          vote_type: u8,
                                          expire: u64,
                                         choice_codes: vector<u8>,
                                         choice_names: vector<vector<u8>>,
                                         choice_thresholds: vector<u64>,
                                          dao: &mut Dao,
                                          sclock: &Clock,
                                          snapshotReg: &DaoSnapshotConfig,
                                          version: &mut Version,
                                          ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let power = snapshot::getVotingPower(sender(ctx), snapshotReg);
        assert!( power >= snapshot::getThresholdSnapshot(snapshotReg) , ERR_ACCESS_DENIED);

        submitProposal(name, description, thread_link, type, vote_power_threshold,
            vote_type, expire, choice_codes, choice_names, choice_thresholds, dao, sclock, ctx);
    }

    fun submitProposal(name: vector<u8>,
                       description: vector<u8>,
                       thread_link: vector<u8>,
                       type: u8,
                       vote_power_threshold: u64,
                       vote_type: u8,
                       expire: u64,
                       choice_codes: vector<u8>,
                       choice_names: vector<vector<u8>>,
                       choice_thresholds: vector<u64>,
                       dao: &mut Dao,
                       sclock: &Clock,
                       ctx: &mut TxContext){

        assert!(vector::length(&description) > 0
                && vector::length(&thread_link) > 0
                && (type == PROPOSAL_TYPE_ONCHAIN || type == PROPOSAL_TYPE_OFFCHAIN)
                && (vote_type == PROPOSAL_VOTE_TYPE_SINGLE || vote_type == PROPOSAL_VOTE_TYPE_MULTI_WEIGHT)
                && expire > clock::timestamp_ms(sclock)
                && vector::length(&choice_codes) > 0
                &&(vector::length(&choice_codes) == vector::length(&choice_names))
                && (vector::length(&choice_codes) == vector::length(&choice_thresholds)),
            ERR_INVALID_PARAMS);

        let prop = Proposal{
            id: object::new(ctx),
            owner: sender(ctx),
            state: PROP_STATE_INIT,
            name,
            description,
            thread_link,
            type,
            vote_power_threshold,
            vote_type,
            choices: vec_map::empty(),
            user_votes: table::new(ctx),
            expire
        };

        while (!vector::is_empty(&choice_codes)){
            addProposalChoice(vector::pop_back(&mut choice_codes),
                        vector::pop_back(&mut choice_names),
                    vector::pop_back(&mut choice_thresholds),
            &mut prop);
        };

        let id= id_address(&prop);

        let event = ProposalSubmittedEvent {
            id,
            state: prop.state,
            name,
            description,
            thread_link,
            type,
            vote_power_threshold,
            vote_type,
            expire
        };

        table::add(&mut dao.proposals, id_address(&prop), prop);

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

    public fun listProposal(proposalId: address,
                            dao: &mut Dao,
                            sclock: &Clock,
                            version: &mut Version,
                            ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let prop = table::borrow_mut(&mut dao.proposals, proposalId);
        assert!(prop.owner == sender(ctx), ERR_ACCESS_DENIED);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        assert!(vec_map::size(&prop.choices) > 0 && clock::timestamp_ms(sclock) < prop.expire, ERR_INVALID_PARAMS);
        prop.state  = PROP_STATE_PENDING;

        emit(ProposalListedEvent {
            id: proposalId,
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

    public fun delistProposal(proposalId: address,
                                dao: &mut Dao,
                                version: &mut Version,
                                ctx: &mut TxContext){
        checkVersion(version, VERSION);

        assert!(table::contains(&dao.proposals, proposalId), ERR_PROPOSAL_NOT_FOUND);
        let prop = table::borrow_mut(&mut dao.proposals, proposalId);
        assert!(prop.owner == sender(ctx), ERR_ACCESS_DENIED);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        prop.state  = PROP_STATE_DELISTED;

        emit(ProposalDelistedEvent {
            id: proposalId,
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

        destroyProposal(table::remove(&mut dao.proposals, proposalId));
    }

    ///
    /// Vote using power staked by snapshot
    ///
    public fun voteByStakedPower(propAddr: address,
                                 dao: &mut Dao,
                                 choices: vector<u8>,
                                 choice_values: vector<u64>,
                                 snapshotReg: &DaoSnapshotConfig,
                                 sclock: &Clock,
                                 version: &mut Version,
                                 ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN , ERR_INVALID_STATE);

        //valid choices ?
        assert!(vector::length(&choices) == vector::length(&choice_values) && vector::length(&choices) > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let powerAmt = snapshot::getVotingPower(sender(ctx), snapshotReg);
        let userVote = distributeVote(prop, choices, choice_values, powerAmt, ctx);

        //event
        emit(ProposalVotedEvent {
            id: propAddr,
            user_vote: userVote
        })
    }

    ///
    /// Directly vote by coin list
    ///
    public fun voteByToken<TOKEN: key + store>(propAddr: address,
                                               dao: &mut Dao,
                                               choices: vector<u8>,
                                               choice_values: vector<u64>,
                                               coins: &Coin<TOKEN>,
                                               snapshotReg: &DaoSnapshotConfig,
                                               sclock: &Clock,
                                               version: &mut Version,
                                               ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN , ERR_INVALID_STATE);

        //whitelisted ?
        assert!(snapshot::isTokenVoteWhitelisted<TOKEN>(snapshotReg), ERR_INVALID_TOKEN_NFT);

        //valid choices ?
        assert!(vector::length(&choices) == vector::length(&choice_values) && vector::length(&choices) > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let factor = snapshot::getTokenBoostFactor<TOKEN>(snapshotReg);
        let power = factor * coin::value(coins);
        let userVote = distributeVote(prop, choices, choice_values, power, ctx);

        //event
        emit(ProposalVotedEvent {
            id: propAddr,
            user_vote: userVote
        })
    }


    ///
    /// Directly vote by NFT collection
    ///
    public fun voteByNfts<NFT: key + store>(propAddr: address,
                                            dao: &mut Dao,
                                            choices: vector<u8>,
                                            choice_values: vector<u64>,
                                            nfts: vector<NFT>,
                                            snapshotReg: &DaoSnapshotConfig,
                                            sclock: &Clock,
                                            version: &mut Version,
                                            ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN, ERR_INVALID_STATE);

        //white listed ?
        assert!(snapshot::isNftVoteWhitelisted<NFT>(snapshotReg), ERR_INVALID_TOKEN_NFT);

        assert!(vector::length(&choices) == vector::length(&choice_values) && vector::length(&choices) > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let factor = snapshot::getNftBoostFactor<NFT>(snapshotReg);
        let power = factor * vector::length(&nfts);
        let userVote = distributeVote(prop, choices, choice_values, power, ctx);

        //return nfts
        transferVector(nfts, sender(ctx));

        //event
        emit(ProposalVotedEvent {
            id: propAddr,
            user_vote: userVote
        })
    }

    ///
    /// Directly vote by anounymous
    /// @todo consider charge fee for anonymous
    ///
    public fun voteByAnonymous(propAddr: address,
                               dao: &mut Dao,
                               choices: vector<u8>,
                               choice_values: vector<u64>,
                               snapshotReg: &DaoSnapshotConfig,
                               sclock: &Clock,
                               version: &mut Version,
                               ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN, ERR_INVALID_STATE);

        //distribute vote
        let power = snapshot::getAnonymousBoostFactor(snapshotReg);
        let userVote = distributeVote(prop, choices, choice_values, power, ctx);

        //event
        emit(ProposalVotedEvent {
            id: propAddr,
            user_vote: userVote
        })
    }

    public fun unvote(propAddr: address,
                      dao: &mut Dao,
                      sclock: &Clock,
                      version: &mut Version,
                      ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut(&mut dao.proposals, propAddr);
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
            id: propAddr,
            user_vote: userVote
        })
    }

    ///
    /// Finalize proposal
    ///
    public fun finalize(_admin: &AdminCap,
                        propAddr: address,
                        dao: &mut Dao,
                        sclock: &Clock,
                        version: &mut Version,
                        _ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut(&mut dao.proposals, propAddr);
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
            id: propAddr,
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
}
