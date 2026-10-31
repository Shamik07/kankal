package main

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

const maxBodyBytes = 1 << 20

func safeRecovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if recover() != nil {
				// The panic value and request details are deliberately omitted.
				writeError(c, http.StatusInternalServerError, "internal_error", "an unexpected error occurred")
			}
		}()
		c.Next()
	}
}

func outcomeDiagnostics() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
		slog.Info("http_request_completed", "method", c.Request.Method, "status", c.Writer.Status())
	}
}

func bearerAuth(token string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		const prefix = "Bearer "
		provided := strings.TrimPrefix(header, prefix)
		providedHash, tokenHash := sha256.Sum256([]byte(provided)), sha256.Sum256([]byte(token))
		if !strings.HasPrefix(header, prefix) || subtle.ConstantTimeCompare(providedHash[:], tokenHash[:]) != 1 {
			writeError(c, 401, "unauthorized", "valid bearer token required")
			c.Abort()
			return
		}
		c.Next()
	}
}
func decodeBody(c *gin.Context, target any) bool {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBodyBytes)
	decoder := json.NewDecoder(c.Request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		if _, ok := err.(*http.MaxBytesError); ok {
			writeError(c, 413, "payload_too_large", "request body exceeds 1 MiB")
		} else {
			writeError(c, 400, "invalid_json", "request body must be a valid JSON object")
		}
		return false
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		writeError(c, 400, "invalid_json", "request body must contain one JSON object")
		return false
	}
	return true
}
func validInput(input itemInput) bool {
	return strings.TrimSpace(input.Title) != "" && len([]rune(input.Title)) <= 200 && len([]rune(input.Description)) <= 2000
}
func writeError(c *gin.Context, status int, code, message string) {
	c.AbortWithStatusJSON(status, gin.H{"error": gin.H{"code": code, "message": message}})
}
