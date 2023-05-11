module gize::snapshot {
    use sui::tx_context::{TxContext, sender};
    use std::vector;
    use sui::object::{UID, id};
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
    use gize::proposal::AdminCap;

    const ERR_ASSET_EXIST: u64 = 1001;
    const ERR_INVALID_ADMIN: u64 = 1002;
    const ERR_BAD_PARAMS: u64 = 1003;

    const VERSION: u64 = 1;

    struct SNAPSHOT has drop {}

    struct AssetSnapshot has key, store {
        id: UID,
        total_object: u64
        //dynamic filed of TypeName > vector<AssetType>
    }

    struct PowerConfig has drop, store, copy {
        power_factor: u64
    }

    struct OperatorConfig has drop, store, copy {
        expire: u64, //expire timestamp
        boost_factor: u64 //power of each operator
    }

    struct DaoSnapshotConfig has key, store {
        id: UID,
        anonymous_boost: PowerConfig,
        operators: Table<address, OperatorConfig>,  //operator roles
        nft_boost: Table<TypeName, PowerConfig>,   //nft whitelist you can stake
        token_boost: Table<TypeName, PowerConfig>,  //token whitelist you can stake
        powers: Table<address, u64>, //user power
        asset_snapshot: Table<address, AssetSnapshot>, //snapshot of asset
        submit_threshold_operator: u64,
        submit_threshold_snapshot: u64,
    }

    fun init(_witness: SNAPSHOT, ctx: &mut TxContext) {
        let sender = sender(ctx);
        assert!(sender == @dao_admin, ERR_INVALID_ADMIN);

        share_object(DaoSnapshotConfig {
            id: object::new(ctx),
            anonymous_boost: PowerConfig{
                power_factor: 0,
            },
            operators: table::new(ctx),
            nft_boost: table::new(ctx),
            token_boost: table::new(ctx),
            powers: table::new(ctx),
            asset_snapshot: table::new(ctx),
            submit_threshold_operator: 0,
            submit_threshold_snapshot: 0,
        })
    }

    public fun setThreshold(_admin: &AdminCap,
                                operatorThreshold: u64,
                                snapshotThreshold: u64,
                                daoConfig: &mut DaoSnapshotConfig,
                                version: &mut Version,
                                _ctx: &mut TxContext){
        checkVersion(version, VERSION);

        daoConfig.submit_threshold_operator = operatorThreshold;
        daoConfig.submit_threshold_snapshot = snapshotThreshold;
    }

    public fun setDaoOperator(_admin: &AdminCap,
                              operatorAddr: address,
                              expireTime: u64,
                              boostFactor: u64,
                              daoConfig: &mut DaoSnapshotConfig,
                              sclock: &Clock,
                              version: &mut Version,
                              _ctx: &mut TxContext){
        checkVersion(version, VERSION);

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
                                 ctx: &mut TxContext){
        checkVersion(version, VERSION);
        configReg.anonymous_boost = PowerConfig {
            power_factor,
        };
    }

    ///@todo make sure that no asset staked on this config while updating config
    public fun addPowerConfigNft<NFT: key + store>(_adminCap: &AdminCap,
                                                   power_factor: u64,
                                                   configReg: &mut DaoSnapshotConfig,
                                                   version: &mut Version,
                                                   ctx: &mut TxContext){
        checkVersion(version, VERSION);
        let typeName = type_name::get<NFT>();
        if(table::contains(&configReg.nft_boost, typeName)){
            table::remove(&mut configReg.nft_boost, typeName);
        };

        table::add(&mut configReg.nft_boost, typeName, PowerConfig {
            power_factor,
        });
    }

    ///@todo make sure that no asset staked on this config while updating config
    public fun addPowerConfigToken<TOKEN>(_adminCap: &AdminCap,
                                          power_factor: u64,
                                          configReg: &mut DaoSnapshotConfig,
                                          version: &mut Version,
                                          ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let typeName = type_name::get<TOKEN>();
        if(table::contains(&configReg.token_boost, typeName)){
            table::remove(&mut configReg.token_boost, typeName);
        };

        table::add(&mut configReg.token_boost, typeName, PowerConfig {
            power_factor,
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
            && table::borrow(&snapshotReg.nft_boost, typeName).power_factor > 0,
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
        common::increaseTable(&mut snapshotReg.powers, senderAddr, nftSize * powerConfig.power_factor);
    }

    ///unstake asset, power reduced
    public fun unstakeSnapshotNft<NFT: key + store>(snapshotReg: &mut DaoSnapshotConfig,
                                                    version: &mut Version,
                                                    ctx: &mut TxContext){
        checkVersion(version, VERSION);

        //validate
        let senderAddr = sender(ctx);
        assert!(table::contains(&snapshotReg.asset_snapshot, senderAddr), ERR_BAD_PARAMS);
        let snapshot = table::borrow_mut(&mut snapshotReg.asset_snapshot, senderAddr);
        let typeName = type_name::get<NFT>();
        assert!(dynamic_field::exists_(&snapshot.id,typeName), ERR_BAD_PARAMS);

        //withdraw all asset branch
        let assetBranch = dynamic_field::remove<TypeName, vector<NFT>>(&mut snapshot.id, typeName);
        let nftSize = vector::length(&assetBranch);
        transferVector(assetBranch, senderAddr);

        //reduce power
        snapshot.total_object = snapshot.total_object - nftSize;
        let powerConfig = table::borrow(&snapshotReg.nft_boost, typeName);
        common::decreaseTable(&mut snapshotReg.powers, senderAddr, nftSize* powerConfig.power_factor);

        if(snapshot.total_object == 0){
            destroyAssetSnapshot(table::remove(&mut snapshotReg.asset_snapshot, senderAddr));
            table::remove(&mut snapshotReg.powers, senderAddr);
        };
    }

    //@fixme review remove dynamic object
    fun destroyAssetSnapshot(snap: AssetSnapshot){
        let AssetSnapshot{
            id,
            total_object: _total_object,
        } = snap;

        object::delete(id);
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
            && table::borrow(&snapshotReg.token_boost, typeName).power_factor > 0,
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
        common::increaseTable(&mut snapshotReg.powers, senderAddr, tokenVal * powerConfig.power_factor);
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
        common::decreaseTable(&mut snapshotReg.powers, senderAddr, tokenVal * powerConfig.power_factor);

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

    public fun getTokenBoostConfig<TOKEN>(snapshotReg: &DaoSnapshotConfig): u64{
        let config = table::borrow(&snapshotReg.token_boost, type_name::get<TOKEN>());
        config.power_factor
    }

    public fun getSnapshotSubmitThreshold(snapshotReg: &DaoSnapshotConfig): u64{
       snapshotReg.submit_threshold_snapshot
    }

    public fun getOperatorSubmitThreshold(snapshotReg: &DaoSnapshotConfig): u64{
        snapshotReg.submit_threshold_operator
    }

    public fun getNftBoostConfig<NFT>(snapshotReg: &DaoSnapshotConfig): u64 {
        let config = table::borrow(&snapshotReg.nft_boost, type_name::get<NFT>());
        config.power_factor
    }

    public fun isOperatorWhitelisted(snapshotReg: &DaoSnapshotConfig, operatorAddr: address): bool{
        table::contains(&snapshotReg.operators, operatorAddr)
    }

    public fun getOperatorBoostConfig(snapshotReg: &DaoSnapshotConfig, operatorAddr: address): (u64, u64){
        let config = table::borrow(&snapshotReg.operators, operatorAddr);
        (config.boost_factor, config.expire)
    }

    public fun getAnonymousBoostConfig(snapshotReg: &DaoSnapshotConfig): u64 {
        let config = snapshotReg.anonymous_boost;
        config.power_factor
    }
}
