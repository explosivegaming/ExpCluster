import React, { useState } from 'react';
import { Tree } from 'antd';
import type { TreeDataNode, TreeProps } from 'antd';

const defaultData: TreeDataNode[] = [
	{
		title: "Group 1",
		key: "G-1",
		icon: false,
		children: [
			{
				title: "Role 1",
				key: "R-1"
			},
			{
				title: "Role 2",
				key: "R-2"
			},
			{
				title: "Role 3",
				key: "R-3"
			}
		]
	},
	{
		title: "Group 2",
		key: "G-2",
		icon: false,
		children: [
			{
				title: "Role 4",
				key: "R-4"
			},
			{
				title: "Role 5",
				key: "R-5"
			}
		]
	},
	{
		title: "Default",
		key: "G-3",
		icon: false,
		children: [
			{
				title: "Role 6",
				key: "R-6"
			}
		]
	}
];

export function GroupTree() {
	const [gData, setGData] = useState(defaultData);

	const onDrop: TreeProps['onDrop'] = (info) => {
		const dropKey = info.node.key;
		const dragKey = info.dragNode.key;
		const dropPos = info.node.pos.split('-');
		const dropPosition = info.dropPosition - Number(dropPos[dropPos.length - 1]); // the drop position relative to the drop node, inside 0, top -1, bottom 1
		
		const findKey = (
			data: TreeDataNode[],
			key: React.Key,
			callback: (node: TreeDataNode, i: number, data: TreeDataNode[]) => void,
		) => {
			for (let i = 0; i < data.length; i++) {
				if (data[i].key === key) {
					return callback(data[i], i, data);
				}
				if (data[i].children) {
					findKey(data[i].children!, key, callback);
				}
			}
		};
		
		const data = [...gData]

		// Find dragObject
		let dragObj: TreeDataNode;
		findKey(data, dragKey, (item, index, arr) => {
			arr.splice(index, 1);
			dragObj = item;
		});

		if (!info.dropToGap) {
			// Drop on the content
			findKey(data, dropKey, (item) => {
				item.children = item.children || [];
				// where to insert. New item was inserted to the start of the array in this example, but can be anywhere
				item.children.unshift(dragObj);
			});
		} else {
			let ar: TreeDataNode[] = [];
			let i: number;
			findKey(data, dropKey, (_item, index, arr) => {
				ar = arr;
				i = index;
			});
			if (dropPosition === -1) {
				// Drop on the top of the drop node
				ar.splice(i!, 0, dragObj!);
			} else {
				// Drop on the bottom of the drop node
				ar.splice(i! + 1, 0, dragObj!);
			}
		}

		setGData(data)
	};

	const allowDrop: TreeProps['allowDrop'] = ({dragNode, dropNode, dropPosition}) => {
		const dragType = (dragNode.key as string).charAt(0);
		const dropType = (dropNode.key as string).charAt(0);
		return dropType === dragType && dropPosition != 0 || dragType === "R" && dropType === "G" && dropPosition == 0
	}

	return (
		<Tree
			className="draggable-tree"
			defaultExpandAll={true}
			draggable
			blockNode
			onDrop={onDrop}
			allowDrop={allowDrop}
			treeData={gData}
		/>
	);
};
