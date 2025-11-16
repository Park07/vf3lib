#ifndef PARALLELMATCHINGTHREADPOOLWLS_HPP
#define PARALLELMATCHINGTHREADPOOLWLS_HPP

#include <omp.h>
#include <vector>
#include <stack>
#include <cstdint>

#include "ARGraph.hpp"
#include "ParallelMatchingEngine.hpp"

namespace vflib {

template<typename VFState>
class ParallelMatchingEngineWLS : public ParallelMatchingEngine<VFState>
{
private:
	uint16_t ssrLimitLevelForGlobalStack;
	uint16_t localStackLimitSize;
	std::vector<std::vector<VFState*>> localStateStack;

public:
	ParallelMatchingEngineWLS(unsigned short int numThreads,
		bool storeSolutions = false,
		bool lockFree = false,
		short int cpu = -1,
		uint16_t ssrLimitLevelForGlobalStack = 3,
		uint16_t localStackLimitSize = 0,
		MatchingVisitor<VFState> *visit = NULL):
		ParallelMatchingEngine<VFState>(numThreads, storeSolutions, lockFree, cpu, visit),
		ssrLimitLevelForGlobalStack(ssrLimitLevelForGlobalStack),
		localStackLimitSize(localStackLimitSize),
		localStateStack(numThreads) {
#ifdef DEBUG
		std::cout << "Started Version VF3PWLS with OpenMP\n";
#endif
	}

	~ParallelMatchingEngineWLS() {}

private:
	void PreMatching(VFState* s) {
		if(!localStackLimitSize) {
			localStackLimitSize = s->GetGraph1()->NodeCount();
		}
	}

	void PutState(VFState* s, ThreadId thread_id) {
		if(thread_id == NULL_THREAD ||
			s->CoreLen() <= ssrLimitLevelForGlobalStack ||
			localStateStack[thread_id].size() > localStackLimitSize) {
			ParallelMatchingEngine<VFState>::PutState(s, thread_id);
		} else {
			// No need for critical section here as each thread has its own local stack
			localStateStack[thread_id].push_back(s);
		}
	}

	void GetState(VFState** res, ThreadId thread_id) {
		*res = NULL;
		// Check local stack first (no sync needed - thread-local)
		if(localStateStack[thread_id].size()) {
			*res = localStateStack[thread_id].back();
			localStateStack[thread_id].pop_back();
		} else {
			ParallelMatchingEngine<VFState>::GetState(res, thread_id);
		}
	}
};

}

#endif