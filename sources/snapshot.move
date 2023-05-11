module gize::snapshot {
    ///
    /// @fixme make sure that no asset staked/unstaked on this while updating config
    ///
    use sui::tx_context::{TxContext, sender};
    use std::vector;
    use sui::object::{UID};
    use sui::transfer::{share_object};
    use std::type_name::TypeName;
    use std::type_name;
    use sui::object;
    use sui::dynamic_field;
    use sui::table::Table;
    use sui::table;
    use sui::coin::Coin;
    use sui::coin;
    use sui::pay;
    use gize::version::{Version, checkVersion};
    use gize::common::transferVector;
    use gize::common;
    use sui::clock::Clock;
    use sui::clock;
    use gize::config::AdminCap;

    const ERR_ASSET_EXIST: u64 = 1001;
    const ERR_INVALID_ADMIN: u64 = 1002;
    const ERR_BAD_PARAMS: u64 = 1003;
    const ERR_SNAPSHOT_RUNNING: u64 = 1004;


    const VERSION: u64 = 1;

    struct SNAPSHOT has drop {}

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

    struct DaoSnapshotConfig has key, store {
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

    fun init(_witness: SNAPSHOT, ctx: &mut TxContext) {
        let sender = sender(ctx);
        assert!(sender == @dao_admin, ERR_INVALID_ADMIN);

        share_object(DaoSnapshotConfig {
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
        })
    }

    public fun setThreshold(_admin: &AdminCap,
                                operatorThreshold: u64,
                                snapshotThreshold: u64,
                                daoConfig: &mut DaoSnapshotConfig,
                                version: &mut Version,
                                _ctx: &mut TxContext){
        checkVersion(version, VERSION);

        daoConfig.threshold_operator = operatorThreshold;
        daoConfig.threshold_snapshot = snapshotThreshold;
    }

    public fun addDaoOperator(_admin: &AdminCap,
                              operatorAddr: address,
                              expireTime: u64,
                              boostFactor: u64,
                              daoConfig: &mut DaoSnapshotConfig,
                              sclock: &Clock,
                              version: &mut Version,
                              _ctx: &mut TxContext){
        checkVersion(version, VERSION);
        assert!(table::length(&daoConfig.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);

        assert!(expireTime > clock::timestamp_ms(sclock), ERR_BAD_PARAMS);
        let daoOps = &mut daoConfig.operators;
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
                                 configReg: &mut DaoSnapshotConfig,
                                 version: &mut Version,
                                 _ctx: &mut TxContext){
        checkVersion(version, VERSION);
        assert!(table::length(&configReg.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);

        assert!(table::length(&configReg.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);
        configReg.anonymous_boost = BoostConfig {
            boost_factor: power_factor,
        };
    }

    public fun setNftBoost<NFT: key + store>(_adminCap: &AdminCap,
                                             power_factor: u64,
                                             configReg: &mut DaoSnapshotConfig,
                                             version: &mut Version,
                                             _ctx: &mut TxContext){
        checkVersion(version, VERSION);
        assert!(table::length(&configReg.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);

        let typeName = type_name::get<NFT>();
        if(table::contains(&configReg.nft_boost, typeName)){
            table::remove(&mut configReg.nft_boost, typeName);
        };

        table::add(&mut configReg.nft_boost, typeName, BoostConfig {
            boost_factor: power_factor,
        });
    }

    public fun setTokenBoost<TOKEN>(_adminCap: &AdminCap,
                                    power_factor: u64,
                                    configReg: &mut DaoSnapshotConfig,
                                    version: &mut Version,
                                    _ctx    : &mut TxContext){
        checkVersion(version, VERSION);
        //@todo more gracefull checking ?
        assert!(table::length(&configReg.asset_snapshot) == 0, ERR_SNAPSHOT_RUNNING);

        let typeName = type_name::get<TOKEN>();
        if(table::contains(&configReg.token_boost, typeName)){
            table::remove(&mut configReg.token_boost, typeName);
        };

        table::add(&mut configReg.token_boost, typeName, BoostConfig {
            boost_factor: power_factor,
        });
    }

    ///stake asset to get more power
    public fun stakeSnapshotNft<NFT: key + store>(nfts: vector<NFT>,
                                                  snapshotReg: &mut DaoSnapshotConfig,
                                                  version: &mut Version,
                                                  ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let nftSize =  vector::length(&nfts);
        let typeName = type_name::get<NFT>();

        //validate
        assert!(nftSize > 0
            && table::contains(&snapshotReg.nft_boost, typeName)
            && table::borrow(&snapshotReg.nft_boost, typeName).boost_factor > 0,
            ERR_BAD_PARAMS);
        let senderAddr = sender(ctx);

        //init snapshot bag
        if(!table::contains(&mut snapshotReg.asset_snapshot, senderAddr)){
            table::add(&mut snapshotReg.asset_snapshot, senderAddr, AssetSnapshot {
                id: object::new(ctx),
                total_object: 0
            })
        };

        let snapshot = table::borrow_mut(&mut snapshotReg.asset_snapshot, senderAddr);
        if(!dynamic_field::exists_(&snapshot.id, typeName)){
            dynamic_field::add(&mut snapshot.id, typeName, vector::empty<NFT>())
        };

        //stake asset
        let assetBranch = dynamic_field::borrow_mut<TypeName, vector<NFT>>(&mut snapshot.id, typeName);
        vector::append(assetBranch, nfts);
        snapshot.total_object = snapshot.total_object + nftSize;

        //update power
        let powerConfig = table::borrow(&snapshotReg.nft_boost, typeName);
        common::increaseTable(&mut snapshotReg.powers, senderAddr, nftSize * powerConfig.boost_factor);
    }

    /// Unstake asset, power reduced
    public fun unstakeSnapshotNft<NFT: key + store>(snapshotReg: &mut DaoSnapshotConfig,
                                                    version: &mut Version,
                                                    ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate
        let senderAddr = sender(ctx);
        assert!(table::contains(&snapshotReg.asset_snapshot, senderAddr), ERR_BAD_PARAMS);
        let snapshot = table::borrow_mut(&mut snapshotReg.asset_snapshot, senderAddr);
        let typeName = type_name::get<NFT>();
        assert!(dynamic_field::exists_(&snapshot.id, typeName), ERR_BAD_PARAMS);

        //withdraw all asset branch
        let assetBranch = dynamic_field::remove<TypeName, vector<NFT>>(&mut snapshot.id, typeName);
        let nftSize = vector::length(&assetBranch);
        transferVector(assetBranch, senderAddr);

        //reduce power
        snapshot.total_object = snapshot.total_object - nftSize;
        let powerConfig = table::borrow(&snapshotReg.nft_boost, typeName);
        common::decreaseTable(&mut snapshotReg.powers, senderAddr, nftSize* powerConfig.boost_factor);

        if(snapshot.total_object == 0){
            destroyAssetSnapshot(table::remove(&mut snapshotReg.asset_snapshot, senderAddr));
            table::remove(&mut snapshotReg.powers, senderAddr);
        };
    }

    ///stake asset to get more power
    public fun stakeSnapshotToken<TOKEN>(tokens: vector<Coin<TOKEN>>,
                                         snapshotReg: &mut DaoSnapshotConfig,
                                         version: &mut Version,
                                         ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let tokenSize =  vector::length(&tokens);
        let typeName = type_name::get<TOKEN>();

        //validate
        assert!(tokenSize > 0
            && table::contains(&snapshotReg.token_boost, typeName)
            && table::borrow(&snapshotReg.token_boost, typeName).boost_factor > 0,
            ERR_BAD_PARAMS);

        let joinedToken = coin::zero<TOKEN>(ctx);
        pay::join_vec(&mut joinedToken, tokens);
        let tokenVal = coin::value(&joinedToken);
        assert!( tokenVal > 0, ERR_BAD_PARAMS);

        let senderAddr = sender(ctx);

        //init snapshot bag
        if(!table::contains(&mut snapshotReg.asset_snapshot, senderAddr)){
            table::add(&mut snapshotReg.asset_snapshot, senderAddr, AssetSnapshot {
                id: object::new(ctx),
                total_object: 0
            })
        };

        let snapshot = table::borrow_mut(&mut snapshotReg.asset_snapshot, senderAddr);
        if(!dynamic_field::exists_(&snapshot.id, typeName)){
            dynamic_field::add(&mut snapshot.id, typeName, vector::empty<Coin<TOKEN>>())
        };

        //stake asset
        let assetBranch = dynamic_field::borrow_mut<TypeName, vector<Coin<TOKEN>>>(&mut snapshot.id, typeName);
        vector::push_back(assetBranch, joinedToken);
        snapshot.total_object = snapshot.total_object + 1;

        //update power
        let powerConfig = table::borrow(&snapshotReg.token_boost, typeName);
        common::increaseTable(&mut snapshotReg.powers, senderAddr, tokenVal * powerConfig.boost_factor);
    }

    ///unstake asset, power reduced
    public fun unstakeSnapshotToken<TOKEN>(snapshotReg: &mut DaoSnapshotConfig,
                                           version: &mut Version,
                                           ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate
        let senderAddr = sender(ctx);
        assert!(table::contains(&snapshotReg.asset_snapshot, senderAddr), ERR_BAD_PARAMS);
        let snapshot = table::borrow_mut(&mut snapshotReg.asset_snapshot, senderAddr);
        let typeName = type_name::get<TOKEN>();
        assert!(dynamic_field::exists_(&snapshot.id, typeName), ERR_BAD_PARAMS);

        //withdraw all asset branch
        let assetBranch = dynamic_field::remove<TypeName, vector<Coin<TOKEN>>>(&mut snapshot.id, typeName);
        let tokenSize = vector::length(&assetBranch);
        let tokenVal = common::totalValue(&assetBranch);

        common::transferVector(assetBranch, senderAddr);

        //reduce power
        snapshot.total_object = snapshot.total_object - tokenSize;
        let powerConfig = table::borrow(&snapshotReg.nft_boost, typeName);
        common::decreaseTable(&mut snapshotReg.powers, senderAddr, tokenVal * powerConfig.boost_factor);

        if(snapshot.total_object == 0){
            destroyAssetSnapshot(table::remove(&mut snapshotReg.asset_snapshot, senderAddr));
            table::remove(&mut snapshotReg.powers, senderAddr);
        };
    }

    ///show voting power
    public fun getVotingPower(user: address, snapshotReg: &DaoSnapshotConfig): u64 {
        if(table::contains(&snapshotReg.powers, user)) {
                *table::borrow(&snapshotReg.powers, user)
        }
        else {
            0u64
        }
    }

    public fun isNftVoteWhitelisted<NFT: key + store>(snapshotReg: &DaoSnapshotConfig): bool{
        table::contains(&snapshotReg.nft_boost, type_name::get<NFT>())
    }

    public fun isTokenVoteWhitelisted<TOKEN>(snapshotReg: &DaoSnapshotConfig): bool{
        table::contains(&snapshotReg.nft_boost, type_name::get<TOKEN>())
    }

    public fun getTokenBoostFactor<TOKEN>(snapshotReg: &DaoSnapshotConfig): u64{
        let config = table::borrow(&snapshotReg.token_boost, type_name::get<TOKEN>());
        config.boost_factor
    }

    public fun getThresholdSnapshot(snapshotReg: &DaoSnapshotConfig): u64{
       snapshotReg.threshold_snapshot
    }

    public fun getThresholdOperator(snapshotReg: &DaoSnapshotConfig): u64{
        snapshotReg.threshold_operator
    }

    public fun getNftBoostFactor<NFT>(snapshotReg: &DaoSnapshotConfig): u64 {
        let config = table::borrow(&snapshotReg.nft_boost, type_name::get<NFT>());
        config.boost_factor
    }

    public fun isOperatorWhitelisted(snapshotReg: &DaoSnapshotConfig, operatorAddr: address): bool{
        table::contains(&snapshotReg.operators, operatorAddr)
    }

    public fun getOperatorBoostFactors(snapshotReg: &DaoSnapshotConfig, operatorAddr: address): (u64, u64){
        let config = table::borrow(&snapshotReg.operators, operatorAddr);
        (config.boost_factor, config.expire)
    }

    public fun getAnonymousBoostFactor(snapshotReg: &DaoSnapshotConfig): u64 {
        let config = snapshotReg.anonymous_boost;
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
