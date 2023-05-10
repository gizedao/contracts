module gize::proposal {
    use sui::object::{UID, id_address};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::{public_transfer, public_share_object};
    use sui::object;
    use std::type_name;
    use sui::table::Table;
    use sui::table;
    use sui::coin::Coin;
    use sui::coin;
    use sui::clock::Clock;
    use sui::clock;
    use sui::vec_set;
    use sui::vec_set::VecSet;
    use sui::event::emit;
    use std::vector;
    use sui::event;
    use sui::vec_map::VecMap;
    use sui::vec_map;
    use std::type_name::TypeName;

    struct PROPOSAL has drop {}


    struct AdminCap has key, store {
        id: UID
    }

    const ONE_UNDRED_SCALED_10000: u64 = 10000;

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


    //@todo add more fields
    struct Proposal has key, store {
        id: UID,
        state: u8,
        name: vector<u8>,
        description: vector<u8>,
        thread_link: vector<u8>, //offchain discussion
        type: u8, //on chain| off chain
        anonymous_boost: u64, //how many power for each anonymous ?
        nft_boost: u64, //how many power for each nft ?
        whitelist_token: VecSet<TypeName>, //must setup when NFT|token condition is required
        whitelist_nft: VecSet<TypeName>, //must setup when NFT|token condition is required
        vote_power_threshold: u64, //minimum power allowed to vote
        vote_type: u8, //single | multiple weighted. multiple equally is one special case
        choices: VecMap<u8, Choice>, //fore example: code -> Choice!
        user_votes: Table<address, UserVote>, //cache user votes, to prevent double votes, support revoking votes
        expire: u64, //expired time
    }

    struct BootConfig has drop, store, copy {
        boost_factor: u64, //multiplied boost factor, for example: anonymous = 100, NFT = 10000, token = 1
        threshold: u64 //min power allowed
    }

    struct OperatorConfig has drop, store, copy {
        expire: u64, //expire timestamp
        boost_factor: u64 //min power allowed
    }

    //@todo more DAO config
    struct Dao has key, store {
        id: UID,
        operators: Table<address, OperatorConfig>,     //operator roles
        nft_boost: Table<TypeName, BootConfig>,    //nft whitelist with boost power
        token_boost: Table<TypeName, BootConfig>,  //which token allowed to make proposal
        proposals: Table<address, Proposal>
    }

    fun init(_witness: PROPOSAL, ctx: &mut TxContext) {
        let sender = sender(ctx);
        assert!(sender == @dao_admin, ERR_INVALID_ADMIN);
        public_transfer(AdminCap { id: object::new(ctx) }, @dao_admin);
    }

    struct ProposalSubmittedEvent has copy, drop {
        id: address,
        state: u8,
        name: vector<u8>,
        description: vector<u8>,
        thread_link: vector<u8>,
        type: u8,
        anonymous_boost: u64,
        nft_boost: u64,
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
        anonymous_boost: u64,
        nft_boost: u64,
        whitelist_token: VecSet<TypeName>,
        whitelist_nft: VecSet<TypeName>,
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
        anonymous_boost: u64,
        nft_boost: u64,
        whitelist_token: VecSet<TypeName>,
        whitelist_nft: VecSet<TypeName>,
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
        thread_link: vector<u8>, //offchain discussion
        type: u8, //on chain| off chain
        anonymous_boost: u64, //how many power for each anonymous ?
        nft_boost: u64, //how many power for each nft ?
        whitelist_token: VecSet<TypeName>, //must setup when NFT|token condition is required
        whitelist_nft: VecSet<TypeName>, //must setup when NFT|token condition is required
        vote_power_threshold: u64, //minimum power allowed to vote
        vote_type: u8, //single | multiple weighted. multiple equally is one special case
        choices: VecMap<u8, Choice>, //fore example: code -> Choice!
        expire: u64, //expired time
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

    public fun createDao(_admin: &AdminCap, ctx: &mut TxContext){
        public_share_object(Dao {
            id: object::new(ctx),
            operators: table::new(ctx),
            nft_boost: table::new(ctx),
            token_boost: table::new(ctx),
            proposals: table::new(ctx)
        });
    }

    public fun setDaoOperator(_admin: &AdminCap, dao: &mut Dao, operatorAddr: address, expireTime: u64, boostFactor: u64, sclock: &Clock, _ctx: &mut TxContext){
        assert!(expireTime > clock::timestamp_ms(sclock), ERR_INVALID_EXPIRE_TIME);
        let registry = &mut dao.operators;
        if(table::contains(registry, operatorAddr)){
            let config = table::borrow_mut(registry, operatorAddr);
            config.expire = expireTime;
            config.boost_factor = boostFactor;
        }
        else{
            table::add( registry, operatorAddr, OperatorConfig {
                boost_factor: boostFactor,
                expire: expireTime
            })
        }
    }

    public fun setDaoRoleBoostConfigNft<NFT: key + store>(_admin: &AdminCap, dao: &mut Dao, boostFactor: u64, threshold: u64, _ctx: &mut TxContext){
        let registry = &mut dao.nft_boost;
        let type = type_name::get<NFT>();
        if(table::contains(registry, type)){
            let config = table::borrow_mut<TypeName, BootConfig>(registry, type);
            config.threshold = threshold;
            config.boost_factor = boostFactor;
        }
        else{
            table::add( registry, type, BootConfig {
                boost_factor: boostFactor,
                threshold
            })
        }
    }

    public fun setDaoRoleBoostConfigToken<TOKEN>(_admin: &AdminCap, dao: &mut Dao, boostFactor: u64, threshold: u64, _ctx: &mut TxContext){
        let registry = &mut dao.token_boost;
        let type = type_name::get<TOKEN>();
        if(table::contains(registry, type)){
            let config = table::borrow_mut<TypeName, BootConfig>(registry, type);
            config.threshold = threshold;
            config.boost_factor = boostFactor;
        }
        else{
            table::add(registry, type, BootConfig {
                boost_factor: boostFactor,
                threshold
            })
        }
    }

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
        submitProposal_(name, description, thread_link, type,
            anonymous_boost, nft_boost, token_condition_threshold, vote_type, expire, dao, ctx);
    }

    public fun submitProposalByOperator(name: vector<u8>,
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
                                        ctx: &mut TxContext) {
        let senderAddr = sender(ctx);
        let operatorReg = &dao.operators;
        assert!(table::contains(operatorReg, senderAddr), ERR_ACCESS_DENIED);
        assert!(table::borrow(operatorReg, senderAddr).expire > clock::timestamp_ms(sclock), ERR_OPERATOR_EXPIRED);
        submitProposal_(name, description, thread_link, type, anonymous_boost, nft_boost, vote_power_threshold, vote_type, expire, dao, ctx);
    }

    //@todo
    public fun submitProposalByToken<TOKEN>(name: vector<u8>,
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
        let reg = &dao.token_boost;
        let tokenType = type_name::get<TOKEN>();
        assert!(table::contains(reg, tokenType), ERR_ACCESS_DENIED);
        let config = table::borrow(reg, tokenType);
        assert!(config.boost_factor * coin::value(token) >= config.threshold , ERR_ACCESS_DENIED);

        submitProposal_(name, description, thread_link, type, anonymous_boost, nft_boost,  vote_power_threshold, vote_type, expire, dao, ctx);
    }

    public fun submitProposalByNfts<NFT: key + store>(name: vector<u8>,
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
                                        ctx: &mut TxContext) {
        let reg = &dao.token_boost;
        let nftType = type_name::get<NFT>();
        assert!(table::contains(reg, nftType), ERR_ACCESS_DENIED);
        let config = table::borrow(reg, nftType);
        assert!(config.boost_factor * vector::length(&nfts) >= config.threshold , ERR_ACCESS_DENIED);
        submitProposal_(name, description, thread_link, type, anonymous_boost, nft_boost,  vote_power_threshold, vote_type, expire, dao, ctx);

        //transfer back to owner
        transfer_objects_vector(nfts, ctx);
    }

    //@todo verify params
    fun submitProposal_(name: vector<u8>,
                        description: vector<u8>,
                        thread_link: vector<u8>,
                        type: u8,
                        anonymous_boost: u64,
                        nft_boost: u64,
                        vote_power_threshold: u64,
                        vote_type: u8,
                        expire: u64,
                        dao: &mut Dao,
                        ctx: &mut TxContext){
        let prop = Proposal{
            id: object::new(ctx),
            state: PROP_STATE_INIT,
            name,
            description,
            thread_link,
            type,
            anonymous_boost,
            nft_boost,
            whitelist_token: vec_set::empty(),
            whitelist_nft: vec_set::empty(),
            vote_power_threshold,
            vote_type,
            choices: vec_map::empty(),
            user_votes: table::new(ctx),
            expire
        };

        let id= id_address(&prop);

        let event = ProposalSubmittedEvent {
            id,
            state: prop.state,
            name,
            description,
            thread_link,
            type,
            anonymous_boost,
            nft_boost,
            vote_power_threshold,
            vote_type,
            expire
        };

        table::add(&mut dao.proposals, id_address(&prop), prop);

        emit(event)
    }

    public fun addProposalWhitelistToken<TOKEN>(_admin: &AdminCap,
                                         propAddr: address,
                                         dao: &mut Dao,
                                         _ctx: &mut TxContext){
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        vec_set::insert(&mut prop.whitelist_token, type_name::get<TOKEN>());
    }

    public fun addProposalWhitelistNft<NFT>(_admin: &AdminCap,
                                         propAddr: address,
                                         dao: &mut Dao,
                                       _ctx: &mut TxContext){
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        vec_set::insert(&mut prop.whitelist_nft, type_name::get<NFT>());
    }

    ///
    /// @todo verify
    ///
    fun addProposalChoice<NFT>(_admin: &AdminCap,
                                code: u8,
                                name: vector<u8>,
                                threshold: u64,
                                propAddr: address,
                                dao: &mut Dao,
                                _ctx: &mut TxContext){
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        assert!(vector::length(&name) > 0 && threshold > 0 && vec_map::contains(&mut prop.choices, &code), ERR_INVALID_CHOICE);
        let choice =  Choice {
            code,
            name,
            total_vote: 0u64,
            threshold
        };

        vec_map::insert(&mut prop.choices, code, choice);

        event::emit(ProposalChoiceAddedEvent {
            id: propAddr,
            choice
        })
    }

    ///
    /// @todo verify
    ///
    fun listProposal(propAddr: address,
                     dao: &mut Dao,
                     _ctx: &mut TxContext){
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        prop.state  = PROP_STATE_PENDING;

        emit(ProposalListedEvent {
            id: propAddr,
            state: prop.state,
            name: prop.name,
            description: prop.description,
            thread_link: prop.thread_link,
            type: prop.type,
            anonymous_boost: prop.anonymous_boost,
            nft_boost: prop.nft_boost,
            whitelist_token: prop.whitelist_token,
            whitelist_nft: prop.whitelist_nft,
            vote_power_threshold: prop.vote_power_threshold,
            vote_type: prop.vote_type,
            choices: prop.choices,
            expire: prop.expire,
        })
    }

    ///
    /// @todo verify
    fun delistProposal(propAddr: address,
                         dao: &mut Dao,
                         _ctx: &mut TxContext){

        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_INIT, ERR_INVALID_STATE);
        prop.state  = PROP_STATE_DELISTED;

        emit(ProposalDelistedEvent {
            id: propAddr,
            state: prop.state,
            name: prop.name,
            description: prop.description,
            thread_link: prop.thread_link,
            type: prop.type,
            anonymous_boost: prop.anonymous_boost,
            nft_boost: prop.nft_boost,
            whitelist_token: prop.whitelist_token,
            whitelist_nft: prop.whitelist_nft,
            vote_power_threshold: prop.vote_power_threshold,
            vote_type: prop.vote_type,
            choices: prop.choices,
            expire: prop.expire,
        });

        destroyProposal(table::remove(&mut dao.proposals, propAddr));
    }

    ///
    /// @todo
    ///
    public fun voteByToken<TOKEN: key + store>(propAddr: address, dao: &mut Dao, choices: vector<u8>, choice_values: vector<u64>, power: &Coin<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN , ERR_INVALID_STATE);

        //whitelisted ?
        assert!(vec_set::contains(&prop.whitelist_token, &type_name::get<TOKEN>()), ERR_INVALID_TOKEN_NFT);

        //valid choices ?
        assert!(vector::length(&choices) == vector::length(&choice_values) && vector::length(&choices) > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let powerAmt = coin::value(power);
        let userVote = distributeVote(prop, choices, choice_values, powerAmt, ctx);

        //event
        emit(ProposalVotedEvent {
            id: propAddr,
            user_vote: userVote
        })
    }

    ///
    /// @todo
    ///
    public fun voteByNfts<NFT: key + store>(propAddr: address, dao: &mut Dao, choices: vector<u8>, choice_values: vector<u64>, nfts: vector<NFT>, sclock: &Clock, ctx: &mut TxContext){
        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN, ERR_INVALID_STATE);

        //white listed ?
        assert!(vec_set::contains(&prop.whitelist_nft, &type_name::get<NFT>()), ERR_INVALID_TOKEN_NFT);

        assert!(vector::length(&choices) == vector::length(&choice_values) && vector::length(&choices) > 0, ERR_INVALID_PARAMS);

        //distribute vote
        let powerAmt = prop.nft_boost * vector::length(&nfts);
        let userVote = distributeVote(prop, choices, choice_values, powerAmt, ctx);

        //return nfts
        transfer_objects_vector(nfts, ctx);

        //event
        emit(ProposalVotedEvent {
            id: propAddr,
            user_vote: userVote
        })
    }

    ///
    /// @todo
    ///
    public fun voteAnonymous(propAddr: address, dao: &mut Dao, choices: vector<u8>, choice_values: vector<u64>, sclock: &Clock, ctx: &mut TxContext){
        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
        assert!(prop.state == PROP_STATE_PENDING &&(now_ms < prop.expire) && prop.type == PROPOSAL_TYPE_ONCHAIN, ERR_INVALID_STATE);

        //distribute vote
        let powerAmt = prop.anonymous_boost;
        let userVote = distributeVote(prop, choices, choice_values, powerAmt, ctx);

        //event
        emit(ProposalVotedEvent {
            id: propAddr,
            user_vote: userVote
        })
    }

    public fun unvote(propAddr: address, dao: &mut Dao, sclock: &Clock, ctx: &mut TxContext){
        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
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

    //Finalize one proposal
    //@todo
    public fun finalize(_admin: &AdminCap, propAddr: address, dao: &mut Dao, sclock: &Clock, _ctx: &mut TxContext){
        //validate params
        assert!(table::contains(&dao.proposals, propAddr), ERR_PROPOSAL_NOT_FOUND);
        let now_ms = clock::timestamp_ms(sclock);
        let prop = table::borrow_mut<address, Proposal>(&mut dao.proposals, propAddr);
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
            anonymous_boost: prop.anonymous_boost,
            nft_boost: prop.nft_boost,
            whitelist_token: prop.whitelist_token,
            whitelist_nft: prop.whitelist_nft,
            vote_power_threshold: prop.vote_power_threshold,
            vote_type: prop.vote_type,
            choices: prop.choices,
            expire: prop.expire,
            total_users: table::length(&prop.user_votes)
        })
    }

    fun distributeVote(prop: &mut Proposal, choices: vector<u8>, choice_values: vector<u64>, power: u64, ctx: &mut TxContext): UserVote {
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
            state: _state,
            name: _name,
            description: _description,
            thread_link: _thread_link,
            type:_type,
            anonymous_boost:_anonymous_boost,
            nft_boost:_nft_boost,
            whitelist_token:_whitelist_token,
            whitelist_nft:_whitelist_nft,
            vote_power_threshold:_vote_power_threshold,
            vote_type:_vote_type,
            choices:_choices,
            user_votes,
            expire:_expire
        } = prop;

        object::delete(id);
        table::drop(user_votes);
    }


    fun transfer_objects_vector<X: key + store>(objects: vector<X>, ctx: &mut TxContext){
        let (index, len, senderAddr)  = (0, vector::length(&objects), sender(ctx));
        while (index < len){
            public_transfer(vector::pop_back(&mut objects), senderAddr);
            index = index + 1;
        };
        vector::destroy_empty(objects);
    }
}
