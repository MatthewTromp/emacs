;;; dom-tests.el --- Tests for dom.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2016-2025 Free Software Foundation, Inc.

;; Author: Simen Heggestøyl <simenheg@gmail.com>
;; Keywords:

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(require 'dom)
(require 'svg)
(require 'ert)

;; `defsubst's are not inlined inside `ert-deftest' (see Bug#24402),
;; therefore we can't use `eval-when-compile' here.
(require 'subr-x)

(defun dom-tests--tree ()
  "Return a DOM tree for testing."
  (dom-node "html" nil
            (dom-node "head" nil
                      (dom-node "title" nil
                                "Test"))
            (dom-node "body" nil
                      (dom-node "div" '((class . "foo")
                                        (style . "color: red;"))
                                (dom-node "p" '((id . "bar"))
                                          "foo"))
                      (dom-node "div" '((title . "2nd div"))
                                "bar"))))

(ert-deftest dom-tests-tag ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-tag dom) "html"))
    (should (equal (dom-tag (car (dom-children dom))) "head"))))

(ert-deftest dom-tests-attributes ()
  (let ((dom (dom-tests--tree)))
    (should-not (dom-attributes dom))
    (should (equal (dom-attributes (dom-by-class dom "foo"))
                   '((class . "foo") (style . "color: red;"))))))

(ert-deftest dom-tests-children ()
  (let ((dom (dom-tests--tree)))
    (should (equal (mapcar #'dom-tag (dom-children dom))
                   '("head" "body")))
    (should (equal (dom-tag (dom-children (dom-children dom)))
                   "title"))))

(ert-deftest dom-tests-non-text-children ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-children dom) (dom-non-text-children dom)))
    (should-not (dom-non-text-children
                 (dom-children (dom-children dom))))))

(ert-deftest dom-tests-set-attributes ()
  (let ((dom (dom-tests--tree))
        (attributes '((xmlns "http://www.w3.org/1999/xhtml"))))
    (should-not (dom-attributes dom))
    (dom-set-attributes dom attributes)
    (should (equal (dom-attributes dom) attributes))))

(ert-deftest dom-tests-set-attribute ()
  (let ((dom (dom-tests--tree))
        (attr 'xmlns)
        (value "http://www.w3.org/1999/xhtml"))
    (should-not (dom-attributes dom))
    (dom-set-attribute dom attr value)
    (should (equal (dom-attr dom attr) value))))

(ert-deftest dom-tests-remove-attribute ()
  (let ((dom (copy-tree '(body ((foo . "bar") (zot . "foobar"))))))
    (should (equal (dom-attr dom 'foo) "bar"))
    (dom-remove-attribute dom 'foo)
    (should (equal (dom-attr dom 'foo) nil))
    (should (equal dom '(body ((zot . "foobar")))))))

(ert-deftest dom-tests-attr ()
  (let ((dom (dom-tests--tree)))
    (should-not (dom-attr dom 'id))
    (should (equal (dom-attr (dom-by-id dom "bar") 'id) "bar"))))

(ert-deftest dom-tests-text ()
  (let ((dom (dom-tests--tree)))
    (should (string-empty-p (dom-text dom)))
    (should (equal (dom-text (dom-by-tag dom "title")) "Test"))))

(ert-deftest dom-tests-texts ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-texts dom) "Test foo bar"))
    (should (equal (dom-texts dom ", ") "Test, foo, bar"))))

(ert-deftest dom-tests-child-by-tag ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-child-by-tag dom "head")
                   (car (dom-children dom))))
    (should-not (dom-child-by-tag dom "title"))))

(ert-deftest dom-tests-by-tag ()
  (let ((dom (dom-tests--tree)))
    (should (= (length (dom-by-tag dom "div")) 2))
    (should-not (dom-by-tag dom "article"))))

(ert-deftest dom-tests-strings ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-strings dom) '("Test" "foo" "bar")))
    (should (equal (dom-strings (dom-children dom)) '("Test")))))

(ert-deftest dom-tests-by-class ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-tag (dom-by-class dom "foo")) "div"))
    (should-not (dom-by-class dom "bar"))))

(ert-deftest dom-tests-by-style ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-tag (dom-by-style dom "color")) "div"))
    (should-not (dom-by-style dom "width"))))

(ert-deftest dom-tests-by-id ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-tag (dom-by-id dom "bar")) "p"))
    (should-not (dom-by-id dom "foo"))))

(ert-deftest dom-tests-elements ()
  (let ((dom (dom-tests--tree)))
    (should (equal (dom-elements dom 'class "foo")
                   (dom-by-class dom "foo")))
    (should (equal (dom-attr (dom-elements dom 'title "2nd") 'title)
                   "2nd div"))))

(ert-deftest dom-tests-remove-node ()
  (let ((dom (dom-tests--tree)))
    (should-not (dom-remove-node dom dom))
    (should (= (length (dom-children dom)) 2))
    (dom-remove-node dom (car (dom-children dom)))
    (should (= (length (dom-children dom)) 1))
    (dom-remove-node dom (car (dom-children dom)))
    (should-not (dom-children dom))))

(ert-deftest dom-tests-parent ()
  (let ((dom (dom-tests--tree)))
    (should-not (dom-parent dom dom))
    (should (equal (dom-parent dom (car (dom-children dom))) dom))))

(ert-deftest dom-tests-previous-sibling ()
  (let ((dom (dom-tests--tree)))
    (should-not (dom-previous-sibling dom dom))
    (let ((children (dom-children dom)))
      (should (equal (dom-previous-sibling dom (cadr children))
                     (car children))))))

(ert-deftest dom-tests-append-child ()
  (let ((dom (dom-tests--tree)))
    (should (equal (mapcar #'dom-tag (dom-children dom))
                   '("head" "body")))
    (dom-append-child dom (dom-node "feet"))
    (should (equal (mapcar #'dom-tag (dom-children dom))
                   '("head" "body" "feet")))))

(ert-deftest dom-tests-add-child-before ()
  "Test `dom-add-child-before'.
Tests the cases of adding a new first-child and mid-child.  Also
checks that an attempt to add a new node before a non-existent
child results in an error."
  (let ((dom (dom-tests--tree)))
    (should (equal (mapcar #'dom-tag (dom-children dom))
                   '("head" "body")))
    (dom-add-child-before dom (dom-node "neck")
                          (dom-child-by-tag dom "body"))
    (should (equal (mapcar #'dom-tag (dom-children dom))
                   '("head" "neck" "body")))
    (dom-add-child-before dom (dom-node "hat"))
    (should (equal (mapcar #'dom-tag (dom-children dom))
                   '("hat" "head" "neck" "body")))
    (should-error (dom-add-child-before dom (dom-node "neck")
                                        (dom-by-id dom "bar")))))

(ert-deftest dom-tests-ensure-node ()
  (let ((node (dom-node "foo")))
    (should (equal (dom-ensure-node '("foo")) node))
    (should (equal (dom-ensure-node '(("foo"))) node))
    (should (equal (dom-ensure-node '("foo" nil)) node))
    (should (equal (dom-ensure-node '(("foo") nil)) node))))

(ert-deftest dom-tests-pp ()
  (let ((node (dom-node "foo" nil "")))
    (with-temp-buffer
      (dom-pp node)
      (should (equal (buffer-string) "(\"foo\" nil\n \"\")")))
    (with-temp-buffer
      (dom-pp node t)
      (should (equal (buffer-string) "(\"foo\" nil)")))))

(ert-deftest dom-tests-print ()
  "Test that `dom-print' correctly encodes HTML reserved characters."
  (with-temp-buffer
    (dom-print '(samp ((class . "samp")) "<div class=\"default\"> </div>"))
    (should (equal
             (buffer-string)
             (concat "<samp class=\"samp\">"
                     "&lt;div class=&quot;default&quot;&gt; &lt;/div&gt;"
                     "</samp>")))))

(ert-deftest dom-tests-print-svg ()
  "Test that `dom-print' correctly print a SVG DOM."
  (let ((svg (svg-create 100 100)))
    (svg-rectangle svg 0 0 "100%" "100%" :fill "blue")
    (svg-text svg "A text" :x 0 :y 55 :stroke "yellow" :fill "yellow")
    (with-temp-buffer
      (dom-print svg t t)
      (should
       (equal
        (buffer-string)
        (concat
         "<svg width=\"100\" height=\"100\" version=\"1.1\" "
         "xmlns=\"http://www.w3.org/2000/svg\" "
         "xmlns:xlink=\"http://www.w3.org/1999/xlink\">\n"
         "  <rect width=\"100%\" height=\"100%\" x=\"0\" y=\"0\" fill=\"blue\" />\n"
         "  <text fill=\"yellow\" stroke=\"yellow\" y=\"55\" x=\"0\">A text</text>\n"
         "</svg>"))))))

(ert-deftest dom-tests-print-html-boolean ()
  "Test that `dom-print' correctly print HTML boolean attributes."
  (let ((dom (dom-node
              "html" nil
              (dom-node "head" nil
                        (dom-node "title" nil
                                  "Test boolean attributes"))
              (dom-node "body" nil
                        ;; The following checkboxes are checked
                        (dom-node "input" '((type . "checkbox")
                                            (checked . "")))
                        (dom-node "input" '((type . "checkbox")
                                            (checked . "checked")))
                        (dom-node "input" '((type . "checkbox")
                                            (checked . "true")))
                        (dom-node "input" '((type . "checkbox")
                                            (checked . "false")))
                        ;; The following checkbox is not checked
                        (dom-node "input" '((type . "checkbox")
                                            (checked)))
                        ))))
    (with-temp-buffer
      (dom-print dom)
      (should
       (equal
        (buffer-string)
        (concat
         "<html><head><title>Test boolean attributes</title></head><body>"
         "<input type=\"checkbox\" checked />"
         "<input type=\"checkbox\" checked />"
         "<input type=\"checkbox\" checked />"
         "<input type=\"checkbox\" checked />"
         "<input type=\"checkbox\" />"
         "</body></html>"))))))

(ert-deftest dom-test-search ()
  (let ((dom '(a nil (b nil (c nil)))))
    (should (equal (dom-search dom (lambda (d) (eq (dom-tag d) 'a)))
                   (list dom)))
    (should (equal (dom-search dom (lambda (d) (memq (dom-tag d) '(b c))))
                   (list (car (dom-children dom))
                         (car (dom-children (car (dom-children dom)))))))))

(provide 'dom-tests)
;;; dom-tests.el ends here
