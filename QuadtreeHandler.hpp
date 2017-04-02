/**
* Course: DV142 - 3D-Programming
* Authors: Viktor Enfeldt, Peter Meunier
*
* File: QuadreeHandler.hpp
*
* Class summary:
*	Basic quadree that doesn't split any geometry.
*	Number of levels in the quadtree is specified by NR_OF_QUADREE_LEVELS  in 
*	GlobalSettings.hpp
*/

#ifndef QUADTREEHANDLER_HPP
#define QUADTREEHANDLER_HPP

#include "GlobalResources.hpp"
#include "GlobalSettings.hpp"

#include "FrustumHandler.hpp"

struct Node
{
	int levels;
	DirectX::XMVECTOR boxMin;
	DirectX::XMVECTOR boxMax;
	Node* children[4];
	std::vector<UINT>objects;
};

class Quadtree 
{
public:
	Quadtree(
		DirectX::XMVECTOR newMin = DirectX::XMVectorZero(), 
		DirectX::XMVECTOR newMax = DirectX::XMVectorZero(), 
		int level = NR_OF_QUADREE_LEVELS);
	~Quadtree();

	void constructNode(DirectX::XMVECTOR newMin, DirectX::XMVECTOR newMax, int level, Node* parent);
	void storeObjects(UINT index, DirectX::XMVECTOR vector, Node* node);

	std::vector<UINT> getVisibleObjectIndices(Node* node);

	Node* root = new Node();
	FrustumHandler mFrustum = FrustumHandler();
	int maxLevel = NR_OF_QUADREE_LEVELS;
};


#endif