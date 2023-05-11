module gize::common {
    use sui::transfer::public_transfer;
    use std::vector;
    use sui::coin::Coin;
    use sui::coin;
    use sui::table::Table;
    use sui::table;

    public fun transferVector<T: key + store>(assets: vector<T>, to: address){
        let index = vector::length(&assets);
        while (index > 0){
            public_transfer( vector::pop_back(&mut assets), to);
            index = index - 1;
        };
        vector::destroy_empty(assets);
    }

    public fun totalValue<TOKEN>(coins: &vector<Coin<TOKEN>>): u64 {
        let sum = 0u64;
        let index = vector::length(coins);
        while (index > 0){
            index = index - 1;
            sum = sum + coin::value(vector::borrow(coins, index));
        };
        sum
    }

    public fun increaseTable(tab: &mut Table<address, u64>, key: address, diff: u64){
        let val = if(table::contains(tab, key)){
            table::remove(tab, key)
        }
        else {
            0u64
        };
        val = val + diff;
        table::add(tab, key, val);
    }

    public fun decreaseTable(tab: &mut Table<address, u64>, key: address, diff: u64){
        let val = if(table::contains(tab, key)){
            table::remove(tab, key)
        }
        else {
            0u64
        };
        assert!(val >= diff, 1);
        val = val - diff;
        table::add(tab, key, val);
    }
}
