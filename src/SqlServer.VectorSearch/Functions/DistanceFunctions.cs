/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using System;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using SqlServer.VectorSearch.Types;

namespace SqlServer.VectorSearch.Functions
{
    /// <summary>
    /// Distance and similarity functions for vectors
    /// </summary>
    public static class DistanceFunctions
    {
        /// <summary>
        /// Calculate L2 (Euclidean) distance between two vectors
        /// Formula: sqrt(sum((a[i] - b[i])^2))
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble L2Distance(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return SqlDouble.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            double sum = 0;
            for (int i = 0; i < v1.Dimension; i++)
            {
                double diff = v1.Values[i] - v2.Values[i];
                sum += diff * diff;
            }

            return new SqlDouble(Math.Sqrt(sum));
        }

        /// <summary>
        /// Calculate squared L2 distance (faster, no sqrt)
        /// Formula: sum((a[i] - b[i])^2)
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble L2SquaredDistance(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return SqlDouble.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            double sum = 0;
            for (int i = 0; i < v1.Dimension; i++)
            {
                double diff = v1.Values[i] - v2.Values[i];
                sum += diff * diff;
            }

            return new SqlDouble(sum);
        }

        /// <summary>
        /// Calculate cosine similarity between two vectors
        /// Formula: (a · b) / (||a|| * ||b||)
        /// Range: [-1, 1] where 1 = identical direction, -1 = opposite
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble CosineSimilarity(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return SqlDouble.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            double dotProduct = 0;
            double norm1 = 0;
            double norm2 = 0;

            for (int i = 0; i < v1.Dimension; i++)
            {
                dotProduct += v1.Values[i] * v2.Values[i];
                norm1 += v1.Values[i] * v1.Values[i];
                norm2 += v2.Values[i] * v2.Values[i];
            }

            norm1 = Math.Sqrt(norm1);
            norm2 = Math.Sqrt(norm2);

            if (norm1 == 0 || norm2 == 0)
                return new SqlDouble(0);

            return new SqlDouble(dotProduct / (norm1 * norm2));
        }

        /// <summary>
        /// Calculate cosine distance (1 - cosine similarity)
        /// Range: [0, 2] where 0 = identical, 2 = opposite
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble CosineDistance(VectorType v1, VectorType v2)
        {
            SqlDouble similarity = CosineSimilarity(v1, v2);
            
            if (similarity.IsNull)
                return SqlDouble.Null;

            return new SqlDouble(1.0 - similarity.Value);
        }

        /// <summary>
        /// Calculate inner product (dot product) between two vectors
        /// Formula: sum(a[i] * b[i])
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble InnerProduct(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return SqlDouble.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            double sum = 0;
            for (int i = 0; i < v1.Dimension; i++)
            {
                sum += v1.Values[i] * v2.Values[i];
            }

            return new SqlDouble(sum);
        }

        /// <summary>
        /// Calculate negative inner product (for use with FAISS MaxInnerProduct)
        /// Formula: -sum(a[i] * b[i])
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble NegativeInnerProduct(VectorType v1, VectorType v2)
        {
            SqlDouble ip = InnerProduct(v1, v2);
            
            if (ip.IsNull)
                return SqlDouble.Null;

            return new SqlDouble(-ip.Value);
        }

        /// <summary>
        /// Generic distance function with metric parameter
        /// Supported metrics: L2, COSINE, IP (inner product)
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble VectorDistance(VectorType v1, VectorType v2, SqlString metric)
        {
            if (v1.IsNull || v2.IsNull || metric.IsNull)
                return SqlDouble.Null;

            string metricType = metric.Value.ToUpper().Trim();

            switch (metricType)
            {
                case "L2":
                case "EUCLIDEAN":
                    return L2Distance(v1, v2);

                case "L2_SQUARED":
                    return L2SquaredDistance(v1, v2);

                case "COSINE":
                case "COSINE_SIMILARITY":
                    return CosineSimilarity(v1, v2);

                case "COSINE_DISTANCE":
                    return CosineDistance(v1, v2);

                case "IP":
                case "INNER_PRODUCT":
                case "DOT":
                    return InnerProduct(v1, v2);

                case "NEGATIVE_IP":
                    return NegativeInnerProduct(v1, v2);

                default:
                    throw new ArgumentException($"Unsupported metric type: {metricType}. " +
                        "Supported: L2, COSINE, IP, COSINE_DISTANCE, NEGATIVE_IP");
            }
        }

        /// <summary>
        /// Calculate Manhattan distance (L1 norm)
        /// Formula: sum(|a[i] - b[i]|)
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble ManhattanDistance(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return SqlDouble.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            double sum = 0;
            for (int i = 0; i < v1.Dimension; i++)
            {
                sum += Math.Abs(v1.Values[i] - v2.Values[i]);
            }

            return new SqlDouble(sum);
        }
    }
}
