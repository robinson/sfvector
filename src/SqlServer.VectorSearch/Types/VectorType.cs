/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using System;
using System.Data.SqlTypes;
using System.IO;
using System.Text;
using Microsoft.SqlServer.Server;

namespace SqlServer.VectorSearch.Types
{
    /// <summary>
    /// User-Defined Type for storing vector embeddings in SQL Server
    /// Format: [dimension:int32][values:float32[]]
    /// </summary>
    [Serializable]
    [SqlUserDefinedType(Format.UserDefined, 
                        IsByteOrdered = false, 
                        MaxByteSize = 8000,
                        ValidationMethodName = "ValidateVector")]
    public struct VectorType : INullable, IBinarySerialize
    {
        private float[] _values;
        private bool _isNull;

        /// <summary>
        /// Gets whether this instance is null
        /// </summary>
        public bool IsNull => _isNull;

        /// <summary>
        /// Returns a null instance of VectorType
        /// </summary>
        public static VectorType Null
        {
            get
            {
                VectorType v = new VectorType { _isNull = true };
                return v;
            }
        }

        /// <summary>
        /// Gets the dimension (length) of the vector
        /// </summary>
        public int Dimension => _values?.Length ?? 0;

        /// <summary>
        /// Gets the internal values array
        /// </summary>
        public float[] Values => _values;

        /// <summary>
        /// Creates a VectorType from a float array
        /// </summary>
        public static VectorType FromArray(float[] values)
        {
            if (values == null || values.Length == 0)
                return Null;

            VectorType v = new VectorType
            {
                _values = values,
                _isNull = false
            };
            return v;
        }

        /// <summary>
        /// Parse a string representation of a vector
        /// Format: "[1.0, 2.0, 3.0]" or "1.0,2.0,3.0"
        /// </summary>
        [SqlMethod(OnNullCall = false)]
        public static VectorType Parse(SqlString s)
        {
            if (s.IsNull)
                return Null;

            string input = s.Value.Trim();
            
            // Remove brackets if present
            if (input.StartsWith("[") && input.EndsWith("]"))
                input = input.Substring(1, input.Length - 2);

            // Split by comma and parse floats
            string[] parts = input.Split(',');
            float[] values = new float[parts.Length];

            for (int i = 0; i < parts.Length; i++)
            {
                if (!float.TryParse(parts[i].Trim(), out values[i]))
                {
                    throw new ArgumentException($"Invalid float value at position {i}: {parts[i]}");
                }
            }

            return FromArray(values);
        }

        /// <summary>
        /// Convert the vector to string representation
        /// </summary>
        public override string ToString()
        {
            if (_isNull || _values == null)
                return "NULL";

            StringBuilder sb = new StringBuilder();
            sb.Append("[");
            for (int i = 0; i < _values.Length; i++)
            {
                if (i > 0) sb.Append(",");
                sb.Append(_values[i].ToString("G"));
            }
            sb.Append("]");
            return sb.ToString();
        }

        /// <summary>
        /// Deserialize from binary format
        /// </summary>
        public void Read(BinaryReader reader)
        {
            _isNull = reader.ReadBoolean();
            
            if (!_isNull)
            {
                int dimension = reader.ReadInt32();
                _values = new float[dimension];
                
                for (int i = 0; i < dimension; i++)
                {
                    _values[i] = reader.ReadSingle();
                }
            }
        }

        /// <summary>
        /// Serialize to binary format
        /// </summary>
        public void Write(BinaryWriter writer)
        {
            writer.Write(_isNull);
            
            if (!_isNull && _values != null)
            {
                writer.Write(_values.Length);
                
                for (int i = 0; i < _values.Length; i++)
                {
                    writer.Write(_values[i]);
                }
            }
        }

        /// <summary>
        /// Validation method called by SQL Server
        /// </summary>
        private bool ValidateVector()
        {
            if (_isNull)
                return true;

            // Check dimension is positive
            if (_values == null || _values.Length == 0)
                return false;

            // Check no NaN or Infinity values
            foreach (float value in _values)
            {
                if (float.IsNaN(value) || float.IsInfinity(value))
                    return false;
            }

            // Check size doesn't exceed SQL Server UDT limit
            // 4 bytes per float + 4 bytes for dimension + 1 byte for null flag
            int byteSize = (_values.Length * 4) + 4 + 1;
            if (byteSize > 8000)
                return false;

            return true;
        }

        /// <summary>
        /// Get element at index (1-based for SQL compatibility)
        /// </summary>
        [SqlMethod(OnNullCall = false)]
        public SqlDouble GetElement(SqlInt32 index)
        {
            if (_isNull || index.IsNull)
                return SqlDouble.Null;

            int idx = index.Value - 1; // Convert to 0-based
            
            if (idx < 0 || idx >= _values.Length)
                throw new ArgumentOutOfRangeException(nameof(index), "Index out of bounds");

            return new SqlDouble(_values[idx]);
        }

        /// <summary>
        /// Calculate L2 norm (magnitude) of the vector
        /// </summary>
        [SqlMethod(OnNullCall = false)]
        public SqlDouble L2Norm()
        {
            if (_isNull)
                return SqlDouble.Null;

            double sum = 0;
            foreach (float value in _values)
            {
                sum += value * value;
            }
            
            return new SqlDouble(Math.Sqrt(sum));
        }

        /// <summary>
        /// Normalize the vector to unit length (L2 norm = 1)
        /// </summary>
        [SqlMethod(OnNullCall = false)]
        public VectorType Normalize()
        {
            if (_isNull)
                return Null;

            double norm = L2Norm().Value;
            
            if (norm == 0)
                throw new InvalidOperationException("Cannot normalize zero vector");

            float[] normalized = new float[_values.Length];
            for (int i = 0; i < _values.Length; i++)
            {
                normalized[i] = (float)(_values[i] / norm);
            }

            return FromArray(normalized);
        }

        /// <summary>
        /// Get dimensions as SqlInt32
        /// </summary>
        [SqlMethod(OnNullCall = false)]
        public SqlInt32 GetDimension()
        {
            if (_isNull)
                return SqlInt32.Null;

            return new SqlInt32(Dimension);
        }
    }
}
