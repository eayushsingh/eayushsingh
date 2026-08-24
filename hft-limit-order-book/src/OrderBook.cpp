#include "LOB/OrderBook.hpp"

namespace HFT {

OrderBook::OrderBook() = default;

OrderBook::~OrderBook() {
    // MemoryPools take care of bulk deletion, but we clean maps just in case
    orderMap.clear();
    bidLimitMap.clear();
    askLimitMap.clear();
}

void OrderBook::insertLimit(Limit* limit, Side side) {
    Limit** head = (side == Side::BUY) ? &bidHead : &askHead;
    if (!*head) {
        *head = limit;
        limit->prev = nullptr;
        limit->next = nullptr;
        return;
    }

    Limit* curr = *head;
    Limit* prev = nullptr;

    if (side == Side::BUY) {
        // Higher prices first
        while (curr && curr->price > limit->price) {
            prev = curr;
            curr = curr->next;
        }
    } else {
        // Lower prices first
        while (curr && curr->price < limit->price) {
            prev = curr;
            curr = curr->next;
        }
    }

    if (!prev) { // Insert at head
        limit->next = *head;
        (*head)->prev = limit;
        limit->prev = nullptr;
        *head = limit;
    } else {
        limit->next = curr;
        limit->prev = prev;
        prev->next = limit;
        if (curr) {
            curr->prev = limit;
        }
    }
}

void OrderBook::removeLimit(Limit* limit, Side side) {
    Limit** head = (side == Side::BUY) ? &bidHead : &askHead;
    if (*head == limit) {
        *head = limit->next;
    }
    if (limit->prev) {
        limit->prev->next = limit->next;
    }
    if (limit->next) {
        limit->next->prev = limit->prev;
    }

    if (side == Side::BUY) {
        bidLimitMap.erase(limit->price);
    } else {
        askLimitMap.erase(limit->price);
    }
    limitPool.deallocate(limit);
}

void OrderBook::appendOrder(Limit* limit, Order* order) {
    order->limitParent = limit;
    if (!limit->head) {
        limit->head = order;
        limit->tail = order;
        order->prev = nullptr;
        order->next = nullptr;
    } else {
        order->prev = limit->tail;
        order->next = nullptr;
        limit->tail->next = order;
        limit->tail = order;
    }
    limit->totalVolume += order->qty;
    limit->orderCount++;
}

void OrderBook::removeOrder(Order* order) {
    Limit* limit = order->limitParent;
    if (!limit) return;

    if (limit->head == order) {
        limit->head = order->next;
    }
    if (limit->tail == order) {
        limit->tail = order->prev;
    }
    if (order->prev) {
        order->prev->next = order->next;
    }
    if (order->next) {
        order->next->prev = order->prev;
    }

    limit->totalVolume -= order->qty;
    limit->orderCount--;

    orderMap.erase(order->orderId);
    Side side = order->side;
    orderPool.deallocate(order);

    if (limit->orderCount == 0) {
        removeLimit(limit, side);
    }
}

void OrderBook::addOrder(uint64_t orderId, uint32_t price, uint32_t qty, Side side, std::vector<Trade>& trades) {
    uint32_t remainingQty = qty;

    if (side == Side::BUY) {
        // Match against asks
        while (askHead && price >= askHead->price && remainingQty > 0) {
            Limit* bestAsk = askHead;
            Order* currOrder = bestAsk->head;

            while (currOrder && remainingQty > 0) {
                Order* nextOrder = currOrder->next;
                uint32_t matchQty = std::min(remainingQty, currOrder->qty);
                remainingQty -= matchQty;
                currOrder->qty -= matchQty;
                bestAsk->totalVolume -= matchQty;

                trades.push_back(Trade{currOrder->orderId, orderId, currOrder->price, matchQty});

                if (currOrder->qty == 0) {
                    removeOrder(currOrder);
                }
                currOrder = nextOrder;
            }
        }
    } else {
        // Match against bids
        while (bidHead && price <= bidHead->price && remainingQty > 0) {
            Limit* bestBid = bidHead;
            Order* currOrder = bestBid->head;

            while (currOrder && remainingQty > 0) {
                Order* nextOrder = currOrder->next;
                uint32_t matchQty = std::min(remainingQty, currOrder->qty);
                remainingQty -= matchQty;
                currOrder->qty -= matchQty;
                bestBid->totalVolume -= matchQty;

                trades.push_back(Trade{currOrder->orderId, orderId, currOrder->price, matchQty});

                if (currOrder->qty == 0) {
                    removeOrder(currOrder);
                }
                currOrder = nextOrder;
            }
        }
    }

    // Post any remaining volume to the book
    if (remainingQty > 0) {
        Limit* limit = nullptr;
        if (side == Side::BUY) {
            auto it = bidLimitMap.find(price);
            if (it == bidLimitMap.end()) {
                limit = limitPool.allocate();
                limit->price = price;
                insertLimit(limit, Side::BUY);
                bidLimitMap[price] = limit;
            } else {
                limit = it->second;
            }
        } else {
            auto it = askLimitMap.find(price);
            if (it == askLimitMap.end()) {
                limit = limitPool.allocate();
                limit->price = price;
                insertLimit(limit, Side::SELL);
                askLimitMap[price] = limit;
            } else {
                limit = it->second;
            }
        }

        Order* order = orderPool.allocate();
        order->orderId = orderId;
        order->price = price;
        order->qty = remainingQty;
        order->side = side;
        appendOrder(limit, order);
        orderMap[orderId] = order;
    }
}

void OrderBook::cancelOrder(uint64_t orderId) {
    auto it = orderMap.find(orderId);
    if (it != orderMap.end()) {
        removeOrder(it->second);
    }
}

void OrderBook::modifyOrder(uint64_t orderId, uint32_t newQty) {
    auto it = orderMap.find(orderId);
    if (it == orderMap.end()) return;

    Order* order = it->second;
    Limit* limit = order->limitParent;

    if (newQty < order->qty) {
        // Decrease quantity: retains priority
        limit->totalVolume -= (order->qty - newQty);
        order->qty = newQty;
    } else if (newQty > order->qty) {
        // Increase quantity: loses priority, appended to end of list
        Side side = order->side;
        uint32_t price = order->price;
        removeOrder(order);

        // Re-add to limit
        Limit* targetLimit = nullptr;
        if (side == Side::BUY) {
            targetLimit = bidLimitMap[price];
        } else {
            targetLimit = askLimitMap[price];
        }

        Order* newOrder = orderPool.allocate();
        newOrder->orderId = orderId;
        newOrder->price = price;
        newOrder->qty = newQty;
        newOrder->side = side;
        appendOrder(targetLimit, newOrder);
        orderMap[orderId] = newOrder;
    }
}

Order* OrderBook::getOrder(uint64_t orderId) const {
    auto it = orderMap.find(orderId);
    return (it != orderMap.end()) ? it->second : nullptr;
}

} // namespace HFT
