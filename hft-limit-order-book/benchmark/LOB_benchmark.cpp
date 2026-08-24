#include "LOB/OrderBook.hpp"
#include <chrono>
#include <vector>
#include <numeric>
#include <algorithm>
#include <iostream>
#include <iomanip>

void runLatencyBenchmark() {
    HFT::OrderBook ob;
    std::vector<HFT::Trade> trades;
    trades.reserve(1000);

    const int iterations = 100000;
    std::vector<double> latencies;
    latencies.reserve(iterations);

    // Warm-up
    for (int i = 0; i < 1000; ++i) {
        ob.addOrder(i, 100 + (i % 10), 5, HFT::Side::SELL, trades);
        ob.addOrder(i + 1000, 100 + (i % 10), 5, HFT::Side::BUY, trades);
        trades.clear();
    }

    // Benchmark loop
    for (int i = 0; i < iterations; ++i) {
        uint64_t orderId = i + 2000;
        uint32_t price = 100 + (i % 10);
        uint32_t qty = 5;

        ob.addOrder(orderId, price, qty, HFT::Side::SELL, trades);
        trades.clear();

        auto start = std::chrono::high_resolution_clock::now();
        ob.addOrder(orderId + iterations, price, qty, HFT::Side::BUY, trades);
        auto end = std::chrono::high_resolution_clock::now();

        auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
        latencies.push_back(static_cast<double>(duration));
        trades.clear();
    }

    // Calculate stats
    double sum = std::accumulate(latencies.begin(), latencies.end(), 0.0);
    double mean = sum / iterations;

    std::sort(latencies.begin(), latencies.end());
    double p50 = latencies[iterations * 0.50];
    double p90 = latencies[iterations * 0.90];
    double p99 = latencies[iterations * 0.99];
    double p999 = latencies[iterations * 0.999];

    std::cout << "=========================================================\n";
    std::cout << "             TICK-TO-TRADE LATENCY BENCHMARK             \n";
    std::cout << "=========================================================\n";
    std::cout << "  Iterations : " << iterations << "\n";
    std::cout << "  Mean       : " << std::fixed << std::setprecision(2) << mean << " ns\n";
    std::cout << "  p50 (Med)  : " << p50 << " ns\n";
    std::cout << "  p90        : " << p90 << " ns\n";
    std::cout << "  p99        : " << p99 << " ns\n";
    std::cout << "  p99.9      : " << p999 << " ns\n";
    std::cout << "=========================================================\n";
}

int main() {
    runLatencyBenchmark();
    return 0;
}
