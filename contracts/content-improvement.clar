;; Content Improvement Contract
;; Improves knowledge content quality

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-FEEDBACK-NOT-FOUND (err u502))
(define-constant ERR-REVIEW-NOT-FOUND (err u503))
(define-constant ERR-INVALID-RATING (err u504))

;; Data Variables
(define-data-var next-feedback-id uint u1)
(define-data-var next-review-id uint u1)
(define-data-var total-feedback uint u0)
(define-data-var improvement-threshold uint u70)

;; Data Maps
(define-map user-feedback
  { feedback-id: uint }
  {
    article-id: uint,
    user-address: principal,
    feedback-type: (string-ascii 20),
    rating: uint,
    comment: (string-ascii 500),
    timestamp: uint,
    is-processed: bool
  }
)

(define-map content-reviews
  { review-id: uint }
  {
    article-id: uint,
    reviewer-id: uint,
    quality-score: uint,
    accuracy-score: uint,
    completeness-score: uint,
    clarity-score: uint,
    overall-score: uint,
    review-notes: (string-ascii 500),
    timestamp: uint,
    status: (string-ascii 20)
  }
)

(define-map improvement-suggestions
  { article-id: uint }
  {
    total-feedback: uint,
    average-rating: uint,
    common-issues: (list 5 (string-ascii 50)),
    suggested-improvements: (list 5 (string-ascii 100)),
    priority-score: uint,
    last-updated: uint
  }
)

(define-map quality-metrics
  { article-id: uint }
  {
    readability-score: uint,
    accuracy-score: uint,
    completeness-score: uint,
    user-satisfaction: uint,
    improvement-needed: bool,
    last-assessed: uint
  }
)

(define-map reviewer-performance
  { reviewer-id: uint }
  {
    reviews-completed: uint,
    average-review-time: uint,
    accuracy-rating: uint,
    consistency-score: uint,
    last-review: uint
  }
)

;; Public Functions

;; Submit user feedback
(define-public (submit-feedback
  (article-id uint)
  (feedback-type (string-ascii 20))
  (rating uint)
  (comment (string-ascii 500))
)
  (let
    (
      (feedback-id (var-get next-feedback-id))
    )
    (asserts! (> article-id u0) ERR-INVALID-INPUT)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
    (asserts! (> (len feedback-type) u0) ERR-INVALID-INPUT)

    (map-set user-feedback
      { feedback-id: feedback-id }
      {
        article-id: article-id,
        user-address: tx-sender,
        feedback-type: feedback-type,
        rating: rating,
        comment: comment,
        timestamp: block-height,
        is-processed: false
      }
    )

    (var-set next-feedback-id (+ feedback-id u1))
    (var-set total-feedback (+ (var-get total-feedback) u1))

    (ok feedback-id)
  )
)

;; Submit content review
(define-public (submit-review
  (article-id uint)
  (reviewer-id uint)
  (quality-score uint)
  (accuracy-score uint)
  (completeness-score uint)
  (clarity-score uint)
  (review-notes (string-ascii 500))
)
  (let
    (
      (review-id (var-get next-review-id))
      (overall-score (/ (+ quality-score (+ accuracy-score (+ completeness-score clarity-score))) u4))
    )
    (asserts! (> article-id u0) ERR-INVALID-INPUT)
    (asserts! (> reviewer-id u0) ERR-INVALID-INPUT)
    (asserts! (<= quality-score u100) ERR-INVALID-RATING)
    (asserts! (<= accuracy-score u100) ERR-INVALID-RATING)
    (asserts! (<= completeness-score u100) ERR-INVALID-RATING)
    (asserts! (<= clarity-score u100) ERR-INVALID-RATING)

    (map-set content-reviews
      { review-id: review-id }
      {
        article-id: article-id,
        reviewer-id: reviewer-id,
        quality-score: quality-score,
        accuracy-score: accuracy-score,
        completeness-score: completeness-score,
        clarity-score: clarity-score,
        overall-score: overall-score,
        review-notes: review-notes,
        timestamp: block-height,
        status: "pending"
      }
    )

    (var-set next-review-id (+ review-id u1))

    (ok review-id)
  )
)

;; Process feedback and generate improvement suggestions
(define-public (process-feedback (article-id uint))
  (let
    (
      (current-suggestions (default-to
        { total-feedback: u0, average-rating: u0, common-issues: (list), suggested-improvements: (list), priority-score: u0, last-updated: u0 }
        (map-get? improvement-suggestions { article-id: article-id })
      ))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> article-id u0) ERR-INVALID-INPUT)

    (map-set improvement-suggestions
      { article-id: article-id }
      (merge current-suggestions {
        total-feedback: (+ (get total-feedback current-suggestions) u1),
        last-updated: block-height
      })
    )

    (ok true)
  )
)

;; Update quality metrics
(define-public (update-quality-metrics
  (article-id uint)
  (readability-score uint)
  (accuracy-score uint)
  (completeness-score uint)
  (user-satisfaction uint)
)
  (let
    (
      (improvement-needed (< (/ (+ readability-score (+ accuracy-score (+ completeness-score user-satisfaction))) u4) (var-get improvement-threshold)))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= readability-score u100) ERR-INVALID-RATING)
    (asserts! (<= accuracy-score u100) ERR-INVALID-RATING)
    (asserts! (<= completeness-score u100) ERR-INVALID-RATING)
    (asserts! (<= user-satisfaction u100) ERR-INVALID-RATING)

    (map-set quality-metrics
      { article-id: article-id }
      {
        readability-score: readability-score,
        accuracy-score: accuracy-score,
        completeness-score: completeness-score,
        user-satisfaction: user-satisfaction,
        improvement-needed: improvement-needed,
        last-assessed: block-height
      }
    )

    (ok improvement-needed)
  )
)

;; Mark feedback as processed
(define-public (mark-feedback-processed (feedback-id uint))
  (let
    (
      (feedback (unwrap! (map-get? user-feedback { feedback-id: feedback-id }) ERR-FEEDBACK-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set user-feedback
      { feedback-id: feedback-id }
      (merge feedback { is-processed: true })
    )

    (ok true)
  )
)

;; Update review status
(define-public (update-review-status (review-id uint) (new-status (string-ascii 20)))
  (let
    (
      (review (unwrap! (map-get? content-reviews { review-id: review-id }) ERR-REVIEW-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len new-status) u0) ERR-INVALID-INPUT)

    (map-set content-reviews
      { review-id: review-id }
      (merge review { status: new-status })
    )

    (ok true)
  )
)

;; Update improvement threshold
(define-public (update-improvement-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-threshold u1) (<= new-threshold u100)) ERR-INVALID-INPUT)

    (var-set improvement-threshold new-threshold)

    (ok true)
  )
)

;; Read-only Functions

;; Get user feedback
(define-read-only (get-user-feedback (feedback-id uint))
  (map-get? user-feedback { feedback-id: feedback-id })
)

;; Get content review
(define-read-only (get-content-review (review-id uint))
  (map-get? content-reviews { review-id: review-id })
)

;; Get improvement suggestions
(define-read-only (get-improvement-suggestions (article-id uint))
  (map-get? improvement-suggestions { article-id: article-id })
)

;; Get quality metrics
(define-read-only (get-quality-metrics (article-id uint))
  (map-get? quality-metrics { article-id: article-id })
)

;; Get reviewer performance
(define-read-only (get-reviewer-performance (reviewer-id uint))
  (map-get? reviewer-performance { reviewer-id: reviewer-id })
)

;; Get total feedback count
(define-read-only (get-total-feedback)
  (var-get total-feedback)
)

;; Get improvement threshold
(define-read-only (get-improvement-threshold)
  (var-get improvement-threshold)
)

;; Check if article needs improvement
(define-read-only (needs-improvement (article-id uint))
  (match (map-get? quality-metrics { article-id: article-id })
    metrics (get improvement-needed metrics)
    false
  )
)
