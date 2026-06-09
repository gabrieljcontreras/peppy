"use client";

import { useEffect, useRef, useState, useCallback } from "react";

interface ScrollRevealOptions {
  threshold?: number;
  rootMargin?: string;
  once?: boolean;
}

export function useScrollReveal({
  threshold = 0.15,
  rootMargin = "0px 0px -60px 0px",
  once = true,
}: ScrollRevealOptions = {}) {
  const [isVisible, setIsVisible] = useState(false);
  const elementRef = useRef<Element | null>(null);
  const observerRef = useRef<IntersectionObserver | null>(null);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setIsVisible(true);
      return;
    }

    observerRef.current = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          if (once && observerRef.current && elementRef.current) {
            observerRef.current.unobserve(elementRef.current);
          }
        } else if (!once) {
          setIsVisible(false);
        }
      },
      { threshold, rootMargin }
    );

    if (elementRef.current) {
      observerRef.current.observe(elementRef.current);
    }

    return () => {
      observerRef.current?.disconnect();
    };
  }, [threshold, rootMargin, once]);

  const ref = useCallback((node: Element | null) => {
    if (elementRef.current && observerRef.current) {
      observerRef.current.unobserve(elementRef.current);
    }
    elementRef.current = node;
    if (node && observerRef.current) {
      observerRef.current.observe(node);
    }
  }, []);

  return { ref, isVisible };
}
