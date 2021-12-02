// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


library RankedArray {
    function quickSort(uint[] memory arr, int left, int right) internal pure {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] < pivot) i++;
            while (pivot < arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j) {
            quickSort(arr, left, j);
        }
        if (i < right) {
            quickSort(arr, i, right);
        }
    }

    function sort(uint[] memory data) internal pure returns (uint[] memory) {
        quickSort(data, int(0), int(data.length - 1));
        return data;
    }

    function getIndex(uint[] memory data, uint num) internal pure returns (uint index) {
        index = data.length;
        for(uint i = 0; i < data.length; i++) {
            if (data[i] == num) {
                index = i;
            }
        }
    }

    function getIndexOfAddressArray(address[] memory data, address addr) internal pure returns (uint256 index) {
        index = data.length;
        for (uint i=0; i < data.length; i++) {
            if (data[i] == addr) index = i;
        }
    }
}