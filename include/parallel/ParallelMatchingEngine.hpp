#ifndef PARALLELMATCHINGTHREADPOOL_HPP
#define PARALLELMATCHINGTHREADPOOL_HPP

#include <omp.h>
#include <vector>
#include <stack>
#include <memory>
#include <cstdint>

#ifndef WIN32
#include <unistd.h>
#include <sys/time.h>
#else
#include <Windows.h>
#include <stdint.h>
#endif

#include "WindowsTime.h"
#include "ARGraph.hpp"
#include "MatchingEngine.hpp"
#include "Stack.hpp"

namespace vflib {

typedef unsigned short ThreadId;
constexpr ThreadId NULL_THREAD = (std::numeric_limits<ThreadId>::max)();

// Forward declaration of OpenMPStack
template<typename T>
class OpenMPStack;

template<typename VFState>
class ParallelMatchingEngine : public MatchingEngine<VFState>
{
protected:
	using MatchingEngine<VFState>::solutions;
	using MatchingEngine<VFState>::visit;
	using MatchingEngine<VFState>::solCount;
	using MatchingEngine<VFState>::storeSolutions;
	using MatchingEngine<VFState>::fist_solution_time;

	struct timeval start_time;
	struct timeval pool_time;
	struct timeval exit_time;
	struct timeval eos_time;
	std::vector<struct timeval> thEndOfSearchTime;

	bool once;
	int16_t endThreadCount;
	int16_t cpu;
	int16_t numThreads;
	int32_t statesToBeExplored;
	Stack<VFState*>* globalStateStack;

	virtual void PreMatching(VFState* s){};
	virtual void PreprocessState(ThreadId thread_id){};
	virtual void PostprocessState(ThreadId thread_id){};
	virtual void UnprocessedState(ThreadId thread_id){};

	virtual void PutState(VFState* s, ThreadId thread_id) {
		globalStateStack->push(s);
	}

	virtual void GetState(VFState** res, ThreadId thread_id) {
		*res = nullptr;
		std::shared_ptr<VFState*> stackitem = globalStateStack->pop();
		if(stackitem != nullptr) {
			*res = *(stackitem.get());
		}
	}

	inline unsigned GetRemainingStates() {
		return globalStateStack->size();
	}

	void Run(ThreadId thread_id) {
		VFState* s = NULL;
		int32_t local_states_to_explore;

		while(true) {
			#pragma omp atomic read
			local_states_to_explore = statesToBeExplored;

			if (local_states_to_explore <= 0) break;

			GetState(&s, thread_id);
			if(s) {
				PreprocessState(thread_id);
				ProcessState(s, thread_id);

				#pragma omp atomic
				statesToBeExplored--;

				delete s;
				PostprocessState(thread_id);
			}
			UnprocessedState(thread_id);
		}

		#pragma omp atomic
		endThreadCount++;

		#pragma omp barrier

		#pragma omp single
		{
			gettimeofday(&(eos_time), NULL);
		}
	}

	bool ProcessState(VFState *s, ThreadId thread_id) {
		if (s->IsGoal()) {
			#pragma omp critical(first_solution)
			{
				if (!once) {
					once = true;
					gettimeofday(&(this->fist_solution_time), NULL);
				}
			}

			#pragma omp atomic
			solCount++;

			if(storeSolutions) {
				#pragma omp critical(solution_storage)
				{
					MatchingSolution sol;
					s->GetCoreSet(sol);
					solutions.push_back(sol);
				}
			}

			if (visit) {
				return (*visit)(*s);
			}
			return true;
		}

		if (s->IsDead())
			return false;

		nodeID_t n1 = NULL_NODE, n2 = NULL_NODE;
		while (s->NextPair(&n1, &n2, n1, n2)) {
			if (s->IsFeasiblePair(n1, n2)) {
				ExploreState(s, n1, n2, thread_id);
			}
		}
		return false;
	}

	virtual void ExploreState(VFState *s, nodeID_t n1, nodeID_t n2, ThreadId thread_id) {
		#pragma omp atomic
		statesToBeExplored++;

		VFState* s1 = new VFState(*s);
		s1->AddPair(n1, n2);
		PutState(s1, thread_id);
	}

public:
	ParallelMatchingEngine(unsigned short int numThreads,
		bool storeSolutions = false,
		bool lockFree = false,
		short int cpu = -1,
		MatchingVisitor<VFState> *visit = NULL):
		MatchingEngine<VFState>(visit, storeSolutions),
		thEndOfSearchTime(numThreads),
		once(false),
		endThreadCount(0),
		cpu(cpu),
		numThreads(numThreads),
		statesToBeExplored(0) {
			// Use OpenMP stack implementation
			globalStateStack = new OpenMPStack<VFState*>();

			// Set OpenMP thread affinity if needed
			if (cpu > -1) {
				omp_set_num_threads(numThreads);
			}
#ifdef DEBUG
			std::cout << "Started Version VF3PGSS with OpenMP\n";
#endif
		}

	~ParallelMatchingEngine() {
		delete globalStateStack;
	}

	bool FindAllMatchings(VFState& s) {
		statesToBeExplored = 1;

		PreMatching(&s);
		gettimeofday(&(this->start_time), NULL);

		VFState* s0 = new VFState(s);
		PutState(s0, NULL_THREAD);

		gettimeofday(&(this->pool_time), NULL);

		// Launch OpenMP parallel region
		#pragma omp parallel num_threads(numThreads)
		{
			ThreadId thread_id = omp_get_thread_num();
			Run(thread_id);
		}

		gettimeofday(&(this->exit_time), NULL);

#ifdef VERBOSE
		std::cout << "Pool Started: " << GetElapsedTime(start_time, pool_time) << std::endl;
		std::cout << "Pool Closed: " << GetElapsedTime(pool_time, eos_time) << std::endl;
		std::cout << "Pool Closed: " << GetElapsedTime(eos_time, exit_time) << std::endl;
#endif
		return true;
	}

	inline size_t GetThreadCount() const {
		return numThreads;
	}

	void ResetSolutionCounter() {
		solCount = 0;
		endThreadCount = 0;
		once = false;
	}
};

// OpenMP-based stack implementation - define it here
template<typename T>
class OpenMPStack : public Stack<T> {
private:
	std::stack<std::shared_ptr<T>> data_stack;
	size_t count;

public:
	OpenMPStack() : count(0) {}

	void push(T const& data) {
		#pragma omp critical(stack_push)
		{
			data_stack.push(std::make_shared<T>(data));
			count++;
		}
	}

	std::shared_ptr<T> pop() {
		std::shared_ptr<T> res;
		#pragma omp critical(stack_pop)
		{
			if (!data_stack.empty()) {
				res = data_stack.top();
				data_stack.pop();
				count--;
			}
		}
		return res;
	}

	size_t size() {
		size_t result;
		#pragma omp atomic read
		result = count;
		return result;
	}
};

}

#endif