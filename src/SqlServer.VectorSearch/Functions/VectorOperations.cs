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
    /// Vector arithmetic and manipulation functions
    /// </summary>
    public static class VectorOperations
    {
        /// <summary>
        /// Add two vectors element-wise
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorAdd(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return VectorType.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            float[] result = new float[v1.Dimension];
            for (int i = 0; i < v1.Dimension; i++)
            {
                result[i] = v1.Values[i] + v2.Values[i];
            }

            return VectorType.FromArray(result);
        }

        /// <summary>
        /// Subtract v2 from v1 element-wise
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorSubtract(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return VectorType.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            float[] result = new float[v1.Dimension];
            for (int i = 0; i < v1.Dimension; i++)
            {
                result[i] = v1.Values[i] - v2.Values[i];
            }

            return VectorType.FromArray(result);
        }

        /// <summary>
        /// Multiply vector by scalar
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorMultiply(VectorType v, SqlDouble scalar)
        {
            if (v.IsNull || scalar.IsNull)
                return VectorType.Null;

            float[] result = new float[v.Dimension];
            float s = (float)scalar.Value;
            
            for (int i = 0; i < v.Dimension; i++)
            {
                result[i] = v.Values[i] * s;
            }

            return VectorType.FromArray(result);
        }

        /// <summary>
        /// Divide vector by scalar
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorDivide(VectorType v, SqlDouble scalar)
        {
            if (v.IsNull || scalar.IsNull)
                return VectorType.Null;

            if (scalar.Value == 0)
                throw new DivideByZeroException("Cannot divide vector by zero");

            float[] result = new float[v.Dimension];
            float s = (float)scalar.Value;
            
            for (int i = 0; i < v.Dimension; i++)
            {
                result[i] = v.Values[i] / s;
            }

            return VectorType.FromArray(result);
        }

        /// <summary>
        /// Calculate element-wise multiplication (Hadamard product)
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorHadamard(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return VectorType.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            float[] result = new float[v1.Dimension];
            for (int i = 0; i < v1.Dimension; i++)
            {
                result[i] = v1.Values[i] * v2.Values[i];
            }

            return VectorType.FromArray(result);
        }

        /// <summary>
        /// Normalize vector to unit length (L2 norm = 1)
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorNormalize(VectorType v)
        {
            if (v.IsNull)
                return VectorType.Null;

            return v.Normalize();
        }

        /// <summary>
        /// Create a zero vector of specified dimension
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = true)]
        public static VectorType VectorZero(SqlInt32 dimension)
        {
            if (dimension.IsNull || dimension.Value <= 0)
                throw new ArgumentException("Dimension must be positive");

            float[] zeros = new float[dimension.Value];
            return VectorType.FromArray(zeros);
        }

        /// <summary>
        /// Create a vector filled with a constant value
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorFill(SqlInt32 dimension, SqlDouble value)
        {
            if (dimension.IsNull || dimension.Value <= 0)
                throw new ArgumentException("Dimension must be positive");

            if (value.IsNull)
                return VectorType.Null;

            float[] values = new float[dimension.Value];
            float fillValue = (float)value.Value;
            
            for (int i = 0; i < dimension.Value; i++)
            {
                values[i] = fillValue;
            }

            return VectorType.FromArray(values);
        }

        /// <summary>
        /// Calculate average of multiple vectors
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorAverage(VectorType v1, VectorType v2)
        {
            if (v1.IsNull || v2.IsNull)
                return VectorType.Null;

            if (v1.Dimension != v2.Dimension)
                throw new ArgumentException("Vectors must have the same dimension");

            float[] result = new float[v1.Dimension];
            for (int i = 0; i < v1.Dimension; i++)
            {
                result[i] = (v1.Values[i] + v2.Values[i]) / 2.0f;
            }

            return VectorType.FromArray(result);
        }

        /// <summary>
        /// Calculate sum of all elements in vector
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble VectorSum(VectorType v)
        {
            if (v.IsNull)
                return SqlDouble.Null;

            double sum = 0;
            foreach (float value in v.Values)
            {
                sum += value;
            }

            return new SqlDouble(sum);
        }

        /// <summary>
        /// Calculate mean of vector elements
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble VectorMean(VectorType v)
        {
            if (v.IsNull)
                return SqlDouble.Null;

            double sum = VectorSum(v).Value;
            return new SqlDouble(sum / v.Dimension);
        }

        /// <summary>
        /// Get minimum value in vector
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble VectorMin(VectorType v)
        {
            if (v.IsNull)
                return SqlDouble.Null;

            float min = float.MaxValue;
            foreach (float value in v.Values)
            {
                if (value < min)
                    min = value;
            }

            return new SqlDouble(min);
        }

        /// <summary>
        /// Get maximum value in vector
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static SqlDouble VectorMax(VectorType v)
        {
            if (v.IsNull)
                return SqlDouble.Null;

            float max = float.MinValue;
            foreach (float value in v.Values)
            {
                if (value > max)
                    max = value;
            }

            return new SqlDouble(max);
        }

        /// <summary>
        /// Clamp vector values to range [min, max]
        /// </summary>
        [SqlFunction(IsDeterministic = true, IsPrecise = false)]
        public static VectorType VectorClamp(VectorType v, SqlDouble min, SqlDouble max)
        {
            if (v.IsNull || min.IsNull || max.IsNull)
                return VectorType.Null;

            if (min.Value > max.Value)
                throw new ArgumentException("min must be less than or equal to max");

            float[] result = new float[v.Dimension];
            float minVal = (float)min.Value;
            float maxVal = (float)max.Value;

            for (int i = 0; i < v.Dimension; i++)
            {
                result[i] = Math.Max(minVal, Math.Min(maxVal, v.Values[i]));
            }

            return VectorType.FromArray(result);
        }
    }
}
