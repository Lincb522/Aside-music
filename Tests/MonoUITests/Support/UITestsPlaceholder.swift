// UITestsPlaceholder.swift
// Mono — material3-expressive-theme spec, Task 15
//
// 占位文件,使 MonoUITests 测试 target 在尚未填充集成 / 快照测试用例
// (Task 17 / Task 18)之前可编译通过。
// 本文件不声明任何 XCTestCase 子类;一旦 17.x / 18.x 添加了真正的测试文件,
// 本文件可安全删除。

import Foundation

internal enum _MonoUITestsPlaceholder {
    /// 仅为防止空 target 导致链接器报错的占位常量。
    static let placeholder: String = "material3-expressive-theme::MonoUITests"
}
