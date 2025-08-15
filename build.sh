#!/usr/bin/env bash
swift build && codesign --sign - --entitlements Resources/mem.entitlements --force .build/debug/mem
