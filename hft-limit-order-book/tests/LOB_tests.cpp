#include "LOB/OrderBook.hpp"
#include <cassert>
#include <iostream>

void testBasicMatching() {
    HFT::OrderBook ob;
    std::vector<HFT::Trade> trades;

    // Add Sell order
    ob.addOrder(1, 100, 10, HFT::Side::SELL, trades);
    assert(trades.empty());
    assert(ob.getAsks() != nullptr);
    assert(ob.getAsks()->price == 100);
    assert(ob.getAsks()->totalVolume == 10);

    // Add matching Buy order
    ob.addOrder(2, 100, 10, HFT::Side::BUY, trades);
    assert(trades.size() == 1);
    assert(trades[0].makerOrderId == 1);
    assert(trades[0].takerOrderId == 2);
    assert(trades[0].qty == 10);
    assert(trades[0].price == 100);

    assert(ob.getAsks() == nullptr);
    assert(ob.getBids() == nullptr);

    std::cout << "testBasicMatching PASSED" << std::endl;
}

void testPriorityAndModify() {
    HFT::OrderBook ob;
    std::vector<HFT::Trade> trades;

    ob.addOrder(1, 100, 10, HFT::Side::BUY, trades);
    ob.addOrder(2, 100, 15, HFT::Side::BUY, trades);

    // Modify order 1 - increase qty, should lose priority
    ob.modifyOrder(1, 20);

    // Match 20 qty sell at 100
    ob.addOrder(3, 100, 20, HFT::Side::SELL, trades);
    
    // Since order 1 lost priority, order 2 (15 qty) matches first, then order 1 (remaining 5 qty) matches
    assert(trades.size() == 2);
    assert(trades[0].makerOrderId == 2);
    assert(trades[0].qty == 15);
    assert(trades[1].makerOrderId == 1);
    assert(trades[1].qty == 5);

    std::cout << "testPriorityAndModify PASSED" << std::endl;
}

int main() {
    testBasicMatching();
    testPriorityAndModify();
    std::cout << "All unit tests PASSED!" << std::endl;
    return 0;
}
