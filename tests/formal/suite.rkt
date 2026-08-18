#lang racket/base
;; Runs all formal tests in one importing thread so Rosette owns one initialized term cache.

(require "aggregate-test.rhm"
         "api-test.rhm"
         "engine-test.rkt"
         "hierarchy-test.rhm"
         "snapshot-test.rhm")
