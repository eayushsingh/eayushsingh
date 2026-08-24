#pragma once
#include "MemoryPool.hpp"
#include <unordered_map>
#include <vector>
#include <cstdint>

namespace HFT {

enum class Side : uint8_t {
    BUY = 0,
    SELL = 1
};

struct Order {
    uint64_t orderId;
    uint32_t price;
    uint32_t qty;
    Side side;
    Order* prev = nullptr;
    Order* next = nullptr;
    struct Limit* limitParent = nullptr;
};

struct Limit {
    uint32_t price;
    uint32_t totalVolume = 0;
    uint32_t orderCount = 0;
    Order* head = nullptr;
    Order* tail = nullptr;
    Limit* prev = nullptr;
    Limit* next = nullptr;
};

struct Trade {
    uint64_t makerOrderId;
    uint64_t takerOrderId;
    uint32_t price;
    uint32_t qty;
};

class OrderBook {
private:
    Limit* bidHead = nullptr; // Head of buy limits, sorted descending
    Limit* askHead = nullptr; // Head of sell limits, sorted ascending

    MemoryPool<Order> orderPool;
    MemoryPool<Limit> limitPool;

    std::unordered_map<uint64_t, Order*> orderMap;
    std::unordered_map<uint32_t, Limit*> bidLimitMap;
    std::unordered_map<uint32_t, Limit*> askLimitMap;

    void insertLimit(Limit* limit, Side side);
    void removeLimit(Limit* limit, Side side);
    void appendOrder(Limit* limit, Order* order);
    void removeOrder(Order* order);

public:
    OrderBook();
    ~OrderBook();

    OrderBook(const OrderBook&) = delete;
    OrderBook& operator=(const OrderBook&) = delete;

    void addOrder(uint64_t orderId, uint32_t price, uint32_t qty, Side side, std::vector<Trade>& trades);
    void cancelOrder(uint64_t orderId);
    void modifyOrder(uint64_t orderId, uint32_t newQty);

    Limit* getBids() const { return bidHead; }
    Limit* getAsks() const { return askHead; }
    Order* getOrder(uint64_t orderId) const;
};

} // namespace HFT
